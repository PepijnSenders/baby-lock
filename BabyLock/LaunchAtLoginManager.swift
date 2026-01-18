import Foundation
import ServiceManagement
import AppKit

/// Manages "Launch at Login" functionality using SMAppService (macOS 13+)
class LaunchAtLoginManager {

    /// Enable launch at login
    /// - Returns: true if successful, false if failed
    @discardableResult
    static func enable() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                print("[LaunchAtLogin] Successfully enabled launch at login")
                return true
            } catch {
                print("[LaunchAtLogin] Failed to enable launch at login: \(error)")
                showRegistrationError(action: "enable", error: error)
                return false
            }
        } else {
            print("[LaunchAtLogin] Launch at login requires macOS 13.0 or later")
            return false
        }
    }

    /// Disable launch at login
    /// - Returns: true if successful, false if failed
    @discardableResult
    static func disable() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                print("[LaunchAtLogin] Successfully disabled launch at login")
                return true
            } catch {
                print("[LaunchAtLogin] Failed to disable launch at login: \(error)")
                showRegistrationError(action: "disable", error: error)
                return false
            }
        } else {
            print("[LaunchAtLogin] Launch at login requires macOS 13.0 or later")
            return false
        }
    }

    /// Toggle launch at login setting
    static func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    /// Shows an alert when registration fails
    private static func showRegistrationError(action: String, error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Launch at Login Failed"
            alert.informativeText = "Failed to \(action) launch at login: \(error.localizedDescription)\n\nThe app will continue working normally, but you may need to manually add it to Login Items in System Settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Check if launch at login is currently enabled
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    /// Check if launch at login feature is available on this system
    static var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
}
