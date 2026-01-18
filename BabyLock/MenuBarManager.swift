import AppKit

/// Manages the menu bar status item, menu, and icon updates.
/// Extracts menu bar responsibilities from AppDelegate for better separation of concerns.
class MenuBarManager {
    var statusItem: NSStatusItem?
    private weak var delegate: MenuBarManagerDelegate?
    private var permissionMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    init(delegate: MenuBarManagerDelegate) {
        self.delegate = delegate
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if statusItem?.button != nil {
            updateIcon(locked: false)
        }

        let menu = NSMenu()
        menu.delegate = delegate as? NSMenuDelegate

        // Permission status item (will be updated dynamically)
        permissionMenuItem = NSMenuItem(title: "Accessibility: Checking...", action: #selector(delegate?.openAccessibilitySettings), keyEquivalent: "")
        permissionMenuItem?.target = delegate as AnyObject
        menu.addItem(permissionMenuItem!)
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Lock (Cmd+Shift+B)", action: #selector(delegate?.toggleLock), keyEquivalent: "")
        toggleItem.target = delegate as AnyObject
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())

        // Launch at Login menu item
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(delegate?.toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem?.target = delegate as AnyObject
        menu.addItem(launchAtLoginMenuItem!)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Initial permission check
        updatePermissionStatus()
    }

    func updateIcon(locked: Bool) {
        guard let button = statusItem?.button else { return }

        let permissionGranted = AccessibilityPermission.isGranted()

        if !permissionGranted && !locked {
            // Show warning state when permission is missing
            if let warningImage = NSImage(systemSymbolName: "lock.trianglebadge.exclamationmark", accessibilityDescription: "Baby Lock - Permission Required") {
                button.image = warningImage
            } else {
                // Fallback: create composite image with exclamation badge
                button.image = createWarningBadgeIcon()
            }
            button.toolTip = "Baby Lock - Accessibility Permission Required"
        } else {
            let symbolName = locked ? "lock.fill" : "lock.open"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Baby Lock")
            button.toolTip = locked ? "Baby Lock - Locked" : "Baby Lock - Unlocked"
        }
    }

    func updatePermissionStatus() {
        let granted = AccessibilityPermission.isGranted()
        if granted {
            permissionMenuItem?.title = "Accessibility: Granted"
            permissionMenuItem?.action = nil  // No action needed when granted
        } else {
            permissionMenuItem?.title = "Accessibility: Not Granted (Click to fix)"
            permissionMenuItem?.action = #selector(delegate?.openAccessibilitySettings)
        }
        print("[MenuBarManager] Permission status: \(granted ? "Granted" : "Not Granted")")

        // Update menu bar icon to reflect permission state
        let isLocked = delegate?.isLocked ?? false
        updateIcon(locked: isLocked)
    }

    func updateLaunchAtLoginStatus() {
        let isEnabled = LaunchAtLoginManager.isEnabled
        launchAtLoginMenuItem?.state = isEnabled ? .on : .off
        print("[MenuBarManager] Launch at Login: \(isEnabled ? "Enabled" : "Disabled")")
    }

    func cleanup() {
        statusItem = nil
    }

    // MARK: - Private Helpers

    /// Creates a lock icon with a warning badge overlay for when accessibility permission is missing.
    private func createWarningBadgeIcon() -> NSImage {
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

/// Protocol for MenuBarManager to communicate with its delegate (AppDelegate).
@objc protocol MenuBarManagerDelegate: AnyObject {
    var isLocked: Bool { get }
    @objc func toggleLock()
    @objc func openAccessibilitySettings()
    @objc func toggleLaunchAtLogin()
}
