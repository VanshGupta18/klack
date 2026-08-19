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
    private var nodes: [AVAudioPlayerNode] = []
    private var playing: [Bool] = []
    private var cursor = 0

    private var buffersByCategory: [KeySoundCategory: [AVAudioPCMBuffer]] = [:]

    var outputVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    init(poolSize: Int = 8) {
        preloadBuffers()

        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            // Connect using the node's own format; the engine mixes formats for us.
            if let format = anyPreloadedFormat() {
                engine.connect(node, to: engine.mainMixerNode, format: format)
            }
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

    // ponytail: assumes every bundled sample shares one PCM format (true for a single
    // recording-session sound pack). If a future pack mixes sample rates/channel counts,
    // convert at load time in preloadBuffers() instead of connecting nodes per-format.
    private func anyPreloadedFormat() -> AVAudioFormat? {
        buffersByCategory.values.first?.first?.format
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
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ) else { continue }
                guard (try? file.read(into: buffer)) != nil else { continue }
                buffers.append(buffer)
            }
            if !buffers.isEmpty {
                buffersByCategory[category] = buffers
            }
        }
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
