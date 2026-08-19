import Carbon.HIToolbox
import CoreGraphics

/// Plain assert-based check for the two pieces of non-trivial, testable-without-the-OS
/// logic in this app. No test framework: this machine's CLT-only toolchain has a broken
/// swift-testing runtime dylib chain, and standing up XCTest isn't possible without a
/// full Xcode.app install. Run via `swift run Klack --self-check`.
func runSelfChecks() -> Bool {
    var failures: [String] = []

    func check(_ name: String, _ condition: Bool) {
        if !condition { failures.append(name) }
    }

    // KeyCategory
    check("space -> .space", KeyCategory.category(for: CGKeyCode(kVK_Space)) == .space)
    check("return -> .enter", KeyCategory.category(for: CGKeyCode(kVK_Return)) == .enter)
    check("keypad enter -> .enter", KeyCategory.category(for: CGKeyCode(kVK_ANSI_KeypadEnter)) == .enter)
    check("delete -> .backspace", KeyCategory.category(for: CGKeyCode(kVK_Delete)) == .backspace)
    check("forward delete -> .backspace", KeyCategory.category(for: CGKeyCode(kVK_ForwardDelete)) == .backspace)
    check("letter A -> .alphanumeric", KeyCategory.category(for: CGKeyCode(kVK_ANSI_A)) == .alphanumeric)
    check("tab falls back to .other", KeyCategory.category(for: CGKeyCode(kVK_Tab)) == .other)
    check("unknown keycode falls back to .other", KeyCategory.category(for: 9999) == .other)

    let shift = CGKeyCode(kVK_Shift)
    check("shift pressed detected", KeyCategory.isModifierPressed(keycode: shift, currentFlags: .maskShift) == true)
    check("shift released detected", KeyCategory.isModifierPressed(keycode: shift, currentFlags: []) == false)
    check("non-modifier keycode -> nil", KeyCategory.isModifierPressed(keycode: CGKeyCode(kVK_ANSI_A), currentFlags: []) == nil)

    // nextNodeIndex (sound-engine pool selection)
    check("picks first idle from cursor", nextNodeIndex(playing: [false, false, false], cursor: 1) == 1)
    check("skips a busy node", nextNodeIndex(playing: [true, false, false], cursor: 0) == 1)
    check("wraps around busy nodes", nextNodeIndex(playing: [false, true, true], cursor: 1) == 0)
    check("steals round-robin when all busy", nextNodeIndex(playing: [true, true, true], cursor: 1) == 1)

    var visited: Set<Int> = []
    var cursor = 0
    let playing = [false, false, false, false]
    for _ in 0..<playing.count {
        let i = nextNodeIndex(playing: playing, cursor: cursor)
        visited.insert(i)
        cursor = (i + 1) % playing.count
    }
    check("full idle round visits every index once", visited == Set(0..<playing.count))

    if failures.isEmpty {
        print("Self-check: all checks passed")
    } else {
        print("Self-check FAILED:")
        for f in failures { print("  - \(f)") }
    }
    return failures.isEmpty
}
