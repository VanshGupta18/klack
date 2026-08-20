import AppKit

final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let soundEngine: SoundEngine

    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    private let mutedItem = NSMenuItem(title: "Sound Muted (Secure Input Active)", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let volumeSlider = NSSlider(value: 0.7, minValue: 0, maxValue: 1, target: nil, action: nil)
    private var themeItems: [NSMenuItem] = []

    var isEnabled = true

    init(soundEngine: SoundEngine) {
        self.soundEngine = soundEngine
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Klack")
        }

        let savedVolume = UserDefaults.standard.object(forKey: "volume") as? Float ?? 0.7
        soundEngine.outputVolume = savedVolume
        volumeSlider.floatValue = savedVolume
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)

        let menu = NSMenu()
        menu.delegate = self

        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)

        mutedItem.isEnabled = false
        mutedItem.isHidden = true
        menu.addItem(mutedItem)

        menu.addItem(.separator())

        let volumeItem = NSMenuItem()
        let volumeView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        volumeSlider.frame = NSRect(x: 20, y: 2, width: 140, height: 20)
        volumeView.addSubview(volumeSlider)
        volumeItem.view = volumeView
        menu.addItem(volumeItem)

        if soundEngine.availableThemes.count > 1 {
            menu.addItem(.separator())
            let themeMenu = NSMenu()
            for theme in soundEngine.availableThemes {
                let item = NSMenuItem(title: theme, action: #selector(selectTheme(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = theme
                item.state = theme == soundEngine.currentTheme ? .on : .off
                themeMenu.addItem(item)
                themeItems.append(item)
            }
            let themeParent = NSMenuItem(title: "Sound Theme", action: nil, keyEquivalent: "")
            themeParent.submenu = themeMenu
            menu.addItem(themeParent)
        }

        menu.addItem(.separator())

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Klack", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        mutedItem.isHidden = !SecureInputMonitor.isEnabled
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledItem.state = isEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? String else { return }
        soundEngine.currentTheme = theme
        for item in themeItems { item.state = (item.representedObject as? String) == theme ? .on : .off }
    }

    @objc private func volumeChanged() {
        soundEngine.outputVolume = volumeSlider.floatValue
        UserDefaults.standard.set(volumeSlider.floatValue, forKey: "volume")
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
