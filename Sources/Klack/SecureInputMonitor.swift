import Foundation

// The CLT-only SDK on this machine ships the linkable symbol but not the declaring
// header (full Xcode.app has it). One extern shim beats a whole separate systemLibrary
// target for a single function.
@_silgen_name("IsSecureEventInputEnabled")
private func c_IsSecureEventInputEnabled() -> DarwinBoolean

enum SecureInputMonitor {
    static var isEnabled: Bool {
        c_IsSecureEventInputEnabled().boolValue
    }
}
