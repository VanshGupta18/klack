import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var soundEngine: SoundEngine!
    private var keyTap: KeyTap!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nothing else stops two copies running at once (e.g. double-clicking again
        // when the menu bar icon isn't immediately visible) — each would independently
        // capture and play every keystroke, sounding like overlapping/mismatched audio.
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.vansh.klack"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != .current }
        if let other = others.first {
            NSLog("Klack: another instance is already running (pid \(other.processIdentifier)) — exiting")
            exit(0)
        }

        // Fire-and-forget: if not yet granted, KeyTap's health-check timer picks up
        // the permission a few seconds after the user grants it, no relaunch needed.
        NSLog("Klack: Input Monitoring already granted at launch: \(CGPreflightListenEventAccess())")
        CGRequestListenEventAccess()

        soundEngine = SoundEngine()
        statusMenu = StatusMenu(soundEngine: soundEngine)

        keyTap = KeyTap()
        keyTap.onKeyDown = { [weak self] keycode in
            guard let self, self.statusMenu.isEnabled else { return }
            self.soundEngine.play(KeyCategory.category(for: keycode))
        }
        keyTap.onModifierChange = { [weak self] keycode, pressed in
            guard let self, self.statusMenu.isEnabled, pressed else { return }
            self.soundEngine.play(.modifier)
        }
    }
}

// LSUIElement in Info.plist handles no-Dock-icon; entry point just needs to be a
// declaration (not top-level code) so the executable target stays `@testable import`-able.
@main
enum KlackMain {
    // NSApplication.delegate is weak — this strong reference is what keeps it alive.
    private static let delegate = AppDelegate()

    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            exit(runSelfChecks() ? 0 : 1)
        }
        if CommandLine.arguments.contains("--verify-sounds") {
            let engine = SoundEngine()
            let counts = engine.loadedSampleCounts
            for category in KeySoundCategory.allCases {
                print("\(category.rawValue): \(counts[category] ?? 0) sample(s) loaded")
            }
            print("Scheduling one playback per category (including fallback-to-alphanumeric ones)...")
            for category in KeySoundCategory.allCases {
                engine.play(category)
            }
            Thread.sleep(forTimeInterval: 1.0)
            print("Playback scheduled with no crash.")
            exit(counts.values.reduce(0, +) > 0 ? 0 : 1)
        }
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
