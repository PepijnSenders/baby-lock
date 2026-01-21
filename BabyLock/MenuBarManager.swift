import AppKit

/// Manages the menu bar status item, menu, and icon updates.
/// Extracts menu bar responsibilities from AppDelegate for better separation of concerns.
class MenuBarManager {
    var statusItem: NSStatusItem?
    private weak var delegate: MenuBarManagerDelegate?
    private var permissionMenuItem: NSMenuItem?
    private var toggleMenuItem: NSMenuItem?

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

        // Toggle Lock menu item with dynamic shortcut display
        let shortcutDisplay = ShortcutConfigurationManager.shared.currentShortcut.displayString
        toggleMenuItem = NSMenuItem(title: "Toggle Lock (\(shortcutDisplay))", action: #selector(delegate?.toggleLock), keyEquivalent: "")
        toggleMenuItem?.target = delegate as AnyObject
        menu.addItem(toggleMenuItem!)

        // Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(delegate?.openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = delegate as AnyObject
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Initial permission check
        updatePermissionStatus()
    }

    func updateIcon(locked: Bool) {
        guard let button = statusItem?.button else { return }

        let permissionGranted = AccessibilityPermission.isGranted()
        let state = IconFactory.state(locked: locked, permissionGranted: permissionGranted)

        button.image = IconFactory.icon(for: state)
        button.toolTip = IconFactory.tooltip(for: state)
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

    func updateShortcutDisplay() {
        let shortcutDisplay = ShortcutConfigurationManager.shared.currentShortcut.displayString
        toggleMenuItem?.title = "Toggle Lock (\(shortcutDisplay))"
        print("[MenuBarManager] Shortcut display updated to: \(shortcutDisplay)")
    }

    func cleanup() {
        statusItem = nil
    }

}

/// Protocol for MenuBarManager to communicate with its delegate (AppDelegate).
@objc protocol MenuBarManagerDelegate: AnyObject {
    var isLocked: Bool { get }
    @objc func toggleLock()
    @objc func openAccessibilitySettings()
    @objc func openSettings()
}
