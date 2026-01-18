import Foundation
import ApplicationServices
import AppKit

/// Utility for checking and requesting macOS Accessibility permission.
/// Required for CGEventTap to intercept system-wide input events.
enum AccessibilityPermission {
    /// Checks if the app has been granted Accessibility permission.
    /// - Returns: `true` if permission is granted, `false` otherwise.
    static func isGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Requests Accessibility permission by showing the system permission dialog.
    /// This will prompt the user to grant access via System Preferences/Settings.
    /// - Returns: `true` if permission is already granted, `false` if user needs to grant it.
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Preferences/Settings to the Accessibility > Privacy pane.
    static func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Shows an alert explaining why Accessibility permission is needed.
    /// - Parameter completion: Called when the alert is dismissed, with `true` if user chose to open System Preferences.
    static func showPermissionAlert(completion: ((Bool) -> Void)? = nil) {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Baby Lock needs Accessibility permission to block keyboard and mouse input when locked.\n\nWithout this permission, the lock feature will not work."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        let openPrefs = (response == .alertFirstButtonReturn)

        if openPrefs {
            openSystemPreferences()
        }

        completion?(openPrefs)
    }
}
