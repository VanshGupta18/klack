import Carbon.HIToolbox
import CoreGraphics

enum KeySoundCategory: String, CaseIterable {
    case alphanumeric, space, enter, backspace, modifier, other
}

enum KeyCategory {
    static let categoryByKeycode: [CGKeyCode: KeySoundCategory] = {
        var m: [CGKeyCode: KeySoundCategory] = [:]

        func mark(_ codes: [Int], _ category: KeySoundCategory) {
            for c in codes { m[CGKeyCode(c)] = category }
        }

        mark([kVK_Space], .space)
        mark([kVK_Return, kVK_ANSI_KeypadEnter], .enter)
        mark([kVK_Delete, kVK_ForwardDelete], .backspace)
        mark([
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F, kVK_ANSI_G,
            kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N,
            kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U,
            kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y, kVK_ANSI_Z,
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
            kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
            kVK_ANSI_Minus, kVK_ANSI_Equal, kVK_ANSI_LeftBracket, kVK_ANSI_RightBracket,
            kVK_ANSI_Backslash, kVK_ANSI_Semicolon, kVK_ANSI_Quote, kVK_ANSI_Comma,
            kVK_ANSI_Period, kVK_ANSI_Slash, kVK_ANSI_Grave,
            kVK_ANSI_Keypad0, kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4,
            kVK_ANSI_Keypad5, kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9,
            kVK_ANSI_KeypadDecimal, kVK_ANSI_KeypadMultiply, kVK_ANSI_KeypadPlus,
            kVK_ANSI_KeypadDivide, kVK_ANSI_KeypadMinus, kVK_ANSI_KeypadEquals,
        ], .alphanumeric)

        return m
    }()

    /// Falls back to `.other` for anything not explicitly mapped (Tab, Escape, arrows, F-keys, Fn, ...).
    static func category(for keycode: CGKeyCode) -> KeySoundCategory {
        categoryByKeycode[keycode] ?? .other
    }

    static let modifierBitByKeycode: [CGKeyCode: CGEventFlags] = [
        CGKeyCode(kVK_Shift): .maskShift,
        CGKeyCode(kVK_RightShift): .maskShift,
        CGKeyCode(kVK_Control): .maskControl,
        CGKeyCode(kVK_RightControl): .maskControl,
        CGKeyCode(kVK_Option): .maskAlternate,
        CGKeyCode(kVK_RightOption): .maskAlternate,
        CGKeyCode(kVK_Command): .maskCommand,
        CGKeyCode(kVK_RightCommand): .maskCommand,
        CGKeyCode(kVK_CapsLock): .maskAlphaShift,
        CGKeyCode(kVK_Function): .maskSecondaryFn,
    ]

    /// nil = not a known modifier keycode. true = this transition was a press, false = a release.
    static func isModifierPressed(keycode: CGKeyCode, currentFlags: CGEventFlags) -> Bool? {
        guard let bit = modifierBitByKeycode[keycode] else { return nil }
        return currentFlags.contains(bit)
    }
}
