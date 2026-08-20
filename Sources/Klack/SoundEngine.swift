import AVFoundation
import Foundation

/// Pure, side-effect-free pool selection: picks the first idle node starting at `cursor`,
/// wrapping around. If every node is busy, steals the next one round-robin rather than
/// growing the pool.
func nextNodeIndex(playing: [Bool], cursor: Int) -> Int {
    guard !playing.isEmpty else { return 0 }
    for offset in 0..<playing.count {
        let i = (cursor + offset) % playing.count
        if !playing[i] { return i }
    }
    return cursor % playing.count
}

final class SoundEngine {
    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private var nodes: [AVAudioPlayerNode] = []
    private var playing: [Bool] = []
    private var cursor = 0
    // Bumped each time a node is (re)used; a stale completion from a buffer that got
    // interrupted (see play()) checks this before clearing `playing`, so it can't
    // mark a node idle out from under whatever new buffer is actually playing on it now.
    private var generation: [Int] = []

    // Every theme is preloaded up front — themes are small (tens of short clips each),
    // so keeping all of them in memory at once means switching is instant with zero
    // runtime file I/O, instead of needing a "reload on switch" mechanism.
    private var buffersByTheme: [String: [KeySoundCategory: [AVAudioPCMBuffer]]] = [:]

    /// Theme names are just the subfolder names under Resources/Sounds/ — discovered at
    /// launch, so adding a new theme later is "drop a folder in," no code change needed.
    let availableThemes: [String]

    private static let themeDefaultsKey = "soundTheme"

    var currentTheme: String {
        didSet { UserDefaults.standard.set(currentTheme, forKey: Self.themeDefaultsKey) }
    }

    var outputVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    /// Diagnostic only (used by `--verify-sounds`): how many samples were actually
    /// found and decoded per category in the CURRENT theme, so a broken bundle path or
    /// a bad audio file shows up as "0 loaded" instead of silent no-op playback.
    var loadedSampleCounts: [KeySoundCategory: Int] {
        (buffersByTheme[currentTheme] ?? [:]).mapValues(\.count)
    }

    init(poolSize: Int = 8) {
        // The hardware output format is available regardless of whether any sample has
        // been loaded yet — connecting nodes against it (rather than a preloaded buffer's
        // format) means the graph is always valid, even with empty sound folders.
        outputFormat = engine.outputNode.inputFormat(forBus: 0)

        let discovered = Self.discoverThemes()
        availableThemes = discovered
        let saved = UserDefaults.standard.string(forKey: Self.themeDefaultsKey)
        currentTheme = (saved.flatMap { discovered.contains($0) ? $0 : nil }) ?? discovered.first ?? "default"

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: outputFormat)
            nodes.append(node)
            playing.append(false)
            generation.append(0)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChange),
            name: .AVAudioEngineConfigurationChange, object: engine
        )

        startEngine()
        for node in nodes { node.play() }

        preloadAllThemes(discovered)
    }

    private func startEngine() {
        engine.prepare()
        do {
            try engine.start()
        } catch {
            NSLog("Klack: engine.start() failed: \(error)")
        }
    }

    @objc private func handleConfigChange() {
        engine.stop()
        startEngine()
    }

    private static func discoverThemes() -> [String] {
        guard let soundsRoot = Bundle.main.resourceURL?.appendingPathComponent("Sounds") else { return [] }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: soundsRoot, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { $0.lastPathComponent }
            .sorted()
    }

    private func preloadAllThemes(_ themes: [String]) {
        guard let soundsRoot = Bundle.main.resourceURL?.appendingPathComponent("Sounds") else { return }
        let fm = FileManager.default

        for theme in themes {
            let themeRoot = soundsRoot.appendingPathComponent(theme)
            var byCategory: [KeySoundCategory: [AVAudioPCMBuffer]] = [:]

            for category in KeySoundCategory.allCases {
                let dir = themeRoot.appendingPathComponent(category.rawValue)
                guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }

                var buffers: [AVAudioPCMBuffer] = []
                for url in files {
                    guard let file = try? AVAudioFile(forReading: url) else { continue }
                    guard let raw = AVAudioPCMBuffer(
                        pcmFormat: file.processingFormat,
                        frameCapacity: AVAudioFrameCount(file.length)
                    ) else { continue }
                    guard (try? file.read(into: raw)) != nil else { continue }
                    guard let converted = convert(raw, to: outputFormat) else { continue }
                    buffers.append(converted)
                }
                if !buffers.isEmpty {
                    byCategory[category] = buffers
                }
            }
            if !byCategory.isEmpty {
                buffersByTheme[theme] = byCategory
            }
        }
    }

    /// Bundled samples won't always share the engine's exact sample rate/channel count
    /// (e.g. a mono 44.1kHz recording against a 48kHz stereo output device) — converting
    /// once at load time keeps every stored buffer playable on nodes connected at `outputFormat`.
    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return conversionError == nil ? output : nil
    }

    /// The entire per-keystroke hot path: pick a random sample, grab an idle node, schedule it.
    /// Falls back to `.alphanumeric` (the largest, most generic bucket) within the current
    /// theme for `.other` keys (Tab, Escape, arrows, F-keys, ...) or any category whose
    /// folder is empty/missing.
    func play(_ category: KeySoundCategory) {
        let themeBuffers = buffersByTheme[currentTheme] ?? [:]
        guard let buffers = themeBuffers[category] ?? themeBuffers[.alphanumeric], !buffers.isEmpty else { return }
        let buffer = buffers[Int.random(in: 0..<buffers.count)]

        let index = nextNodeIndex(playing: playing, cursor: cursor)
        cursor = (index + 1) % max(nodes.count, 1)

        let node = nodes[index]
        playing[index] = true
        generation[index] += 1
        let gen = generation[index]

        // .dataPlayedBack (not the default .dataConsumed): fires only once the audio has
        // actually finished being heard, so `playing` reflects real node state instead of
        // "buffer handed to the render queue" — the default fires almost instantly and was
        // why fast typing built an inaudible-but-tracked-as-idle backlog.
        // .interrupts (not the default, which queues): a node picked while still busy
        // replaces its pending/playing buffer immediately instead of queuing behind it
        // unboundedly — bounds worst case to "one click truncated," never a growing backlog.
        node.scheduleBuffer(
            buffer,
            at: nil,
            options: .interrupts,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation[index] == gen else { return }
                self.playing[index] = false
            }
        }
        if !node.isPlaying { node.play() }
    }
}
