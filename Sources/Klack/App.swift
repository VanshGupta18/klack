import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var soundEngine: SoundEngine!
    private var keyTap: KeyTap!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Fire-and-forget: if not yet granted, KeyTap's health-check timer picks up
        // the permission a few seconds after the user grants it, no relaunch needed.
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
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
