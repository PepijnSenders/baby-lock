import AppKit

/// Factory for creating menu bar icons with various states.
/// Centralizes icon rendering logic for better separation of concerns.
enum IconFactory {

    /// Icon state representing the current application status.
    enum IconState {
        case locked
        case unlocked
        case permissionRequired
    }

    /// Returns the appropriate icon for the given state.
    /// - Parameter state: The current icon state.
    /// - Returns: An NSImage configured for the menu bar.
    static func icon(for state: IconState) -> NSImage? {
        switch state {
        case .locked:
            return NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Baby Lock - Locked")
        case .unlocked:
            return NSImage(systemSymbolName: "lock.open", accessibilityDescription: "Baby Lock - Unlocked")
        case .permissionRequired:
            // Try system symbol first (macOS 14+), fall back to custom composite
            return NSImage(systemSymbolName: "lock.trianglebadge.exclamationmark", accessibilityDescription: "Baby Lock - Permission Required")
                ?? createWarningBadgeIcon()
        }
    }

    /// Returns the tooltip text for the given state.
    /// - Parameter state: The current icon state.
    /// - Returns: A tooltip string.
    static func tooltip(for state: IconState) -> String {
        switch state {
        case .locked:
            return "Baby Lock - Locked"
        case .unlocked:
            return "Baby Lock - Unlocked"
        case .permissionRequired:
            return "Baby Lock - Accessibility Permission Required"
        }
    }

    /// Determines the icon state based on lock status and permission.
    /// - Parameters:
    ///   - locked: Whether the app is currently locked.
    ///   - permissionGranted: Whether accessibility permission is granted.
    /// - Returns: The appropriate icon state.
    static func state(locked: Bool, permissionGranted: Bool) -> IconState {
        if !permissionGranted && !locked {
            return .permissionRequired
        }
        return locked ? .locked : .unlocked
    }

    // MARK: - Private Helpers

    /// Creates a lock icon with a warning badge overlay for when accessibility permission is missing.
    /// Used as a fallback when the system symbol is unavailable.
    private static func createWarningBadgeIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw base lock icon
            if let lockImage = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil) {
                let lockRect = NSRect(x: 0, y: 2, width: 14, height: 14)
                lockImage.draw(in: lockRect)
            }

            // Draw warning badge (small circle with exclamation)
            let badgeRect = NSRect(x: 10, y: 0, width: 8, height: 8)
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()

            // Draw exclamation mark
            let exclamation = NSAttributedString(
                string: "!",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 6),
                    .foregroundColor: NSColor.white
                ]
            )
            let textSize = exclamation.size()
            let textPoint = NSPoint(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2
            )
            exclamation.draw(at: textPoint)

            return true
        }
        image.isTemplate = true
        return image
    }
}
