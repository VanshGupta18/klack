import CoreGraphics
import Foundation

final class KeyTap {
    var onKeyDown: ((CGKeyCode) -> Void)?
    var onModifierChange: ((CGKeyCode, Bool) -> Void)?

    private var port: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthTimer: Timer?

    private static let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

    init() {
        tryCreateTap()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkHealth()
        }
    }

    deinit {
        healthTimer?.invalidate()
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
    }

    private func tryCreateTap() {
        guard port == nil else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let newPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("Klack: CGEventTapCreate failed (Input Monitoring not granted yet?) — will retry")
            return
        }

        port = newPort
        let source = CFMachPortCreateRunLoopSource(nil, newPort, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: newPort, enable: true)
        NSLog("Klack: key tap created and enabled")
    }

    private func checkHealth() {
        guard let port else {
            tryCreateTap()
            return
        }
        if !CGEvent.tapIsEnabled(tap: port) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
        case .keyDown:
            let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            onKeyDown?(keycode)
        case .flagsChanged:
            let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            if let pressed = KeyCategory.isModifierPressed(keycode: keycode, currentFlags: event.flags) {
                onModifierChange?(keycode, pressed)
            }
        default:
            break
        }
        // .listenOnly: return value is ignored by the system; pass the event through unmodified.
        return Unmanaged.passUnretained(event)
    }
}
