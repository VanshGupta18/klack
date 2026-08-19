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

    private var buffersByCategory: [KeySoundCategory: [AVAudioPCMBuffer]] = [:]

    var outputVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    init(poolSize: Int = 8) {
        // The hardware output format is available regardless of whether any sample has
        // been loaded yet — connecting nodes against it (rather than a preloaded buffer's
        // format) means the graph is always valid, even with empty sound folders.
        outputFormat = engine.outputNode.inputFormat(forBus: 0)
        preloadBuffers()

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: outputFormat)
            nodes.append(node)
            playing.append(false)
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChange),
            name: .AVAudioEngineConfigurationChange, object: engine
        )

        startEngine()
        for node in nodes { node.play() }
    }

    private func startEngine() {
        engine.prepare()
        try? engine.start()
    }

    @objc private func handleConfigChange() {
        engine.stop()
        startEngine()
    }

    private func preloadBuffers() {
        let fm = FileManager.default
        guard let soundsRoot = Bundle.main.resourceURL?.appendingPathComponent("Sounds") else { return }

        for category in KeySoundCategory.allCases {
            let dir = soundsRoot.appendingPathComponent(category.rawValue)
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
                buffersByCategory[category] = buffers
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
    func play(_ category: KeySoundCategory) {
        guard let buffers = buffersByCategory[category] ?? buffersByCategory[.other], !buffers.isEmpty else { return }
        let buffer = buffers[Int.random(in: 0..<buffers.count)]

        let index = nextNodeIndex(playing: playing, cursor: cursor)
        cursor = (index + 1) % max(nodes.count, 1)

        let node = nodes[index]
        playing[index] = true
        node.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                self?.playing[index] = false
            }
        }
        if !node.isPlaying { node.play() }
    }
}
