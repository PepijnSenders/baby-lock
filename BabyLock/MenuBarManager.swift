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

    func updateLaunchAtLoginStatus() {
        let isEnabled = LaunchAtLoginManager.isEnabled
        launchAtLoginMenuItem?.state = isEnabled ? .on : .off
        print("[MenuBarManager] Launch at Login: \(isEnabled ? "Enabled" : "Disabled")")
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
    @objc func toggleLaunchAtLogin()
}
