import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let lockManager = LockManager()
    private var cancellables = Set<AnyCancellable>()
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    private var permissionMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var setupGuidanceController: SetupGuidanceWindowController?
    private var permissionPollingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        handleFirstLaunchIfNeeded()
        setupMenuBar()
        observeLockState()
        setupGlobalHotkey()
        startPermissionPollingIfNeeded()
        setupSleepWakeNotifications()
    }

    private func handleFirstLaunchIfNeeded() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunchedBefore {
            print("[AppDelegate] First launch detected")

            // Show setup guidance window
            showSetupGuidance()
        } else {
            print("[AppDelegate] Not first launch, skipping first launch handling")
        }
    }

    private func showSetupGuidance() {
        print("[AppDelegate] Showing setup guidance window")
        setupGuidanceController = SetupGuidanceWindowController()
        setupGuidanceController?.showWindow { [weak self] in
            print("[AppDelegate] Setup guidance dismissed")

            // Request accessibility permission after guidance is dismissed
            print("[AppDelegate] Requesting accessibility permission")
            AccessibilityPermission.requestPermission()

            // Mark as launched
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            print("[AppDelegate] First launch handling complete, hasLaunchedBefore set to true")

            // Clean up controller reference
            self?.setupGuidanceController = nil
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon(locked: false)
        }

        let menu = NSMenu()
        menu.delegate = self

        // Permission status item (will be updated dynamically)
        permissionMenuItem = NSMenuItem(title: "Accessibility: Checking...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(permissionMenuItem!)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Toggle Lock (Cmd+Shift+B)", action: #selector(toggleLock), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Launch at Login menu item
        launchAtLoginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(launchAtLoginMenuItem!)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Initial permission check
        updatePermissionStatus()
    }

    private func observeLockState() {
        lockManager.$isLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                self?.updateMenuBarIcon(locked: isLocked)
            }
            .store(in: &cancellables)
    }

    private func setupGlobalHotkey() {
        // Handler for Cmd+Shift+B hotkey
        let hotkeyHandler: (NSEvent) -> Void = { [weak self] event in
            // Check for keyCode 11 (B key) with Command and Shift modifiers
            // Use rawValue check to ensure we're detecting the correct key combination
            let flags = event.modifierFlags

            if event.keyCode == 11 &&
               flags.contains(.command) &&
               flags.contains(.shift) &&
               !flags.contains(.control) &&
               !flags.contains(.option) {
                print("[GlobalHotkey] Cmd+Shift+B detected (keyCode: \(event.keyCode), flags: \(flags.rawValue))")
                DispatchQueue.main.async {
                    self?.lockManager.toggle()
                }
            }
        }

        // Global monitor: catches hotkey when OTHER apps have focus
        // Requires Accessibility permission
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: hotkeyHandler)

        if globalHotkeyMonitor == nil {
            print("[GlobalHotkey] WARNING: Failed to create global monitor - Accessibility permission may be missing")
        } else {
            print("[GlobalHotkey] Global monitor created successfully")
        }

        // Local monitor: catches hotkey when BabyLock itself has focus (e.g., menu open)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            hotkeyHandler(event)
            return event  // Pass event through
        }

        if localHotkeyMonitor == nil {
            print("[GlobalHotkey] WARNING: Failed to create local monitor")
        } else {
            print("[GlobalHotkey] Local monitor created successfully")
        }

        print("[GlobalHotkey] Hotkey setup complete")
    }

    @objc func toggleLock() {
        // Check permission before allowing lock
        if !lockManager.isLocked && !AccessibilityPermission.isGranted() {
            print("[AppDelegate] Cannot lock - Accessibility permission not granted")
            AccessibilityPermission.showPermissionAlert()
            return
        }
        lockManager.toggle()
    }

    @objc func openAccessibilitySettings() {
        AccessibilityPermission.openSystemPreferences()
    }

    @objc func toggleLaunchAtLogin() {
        LaunchAtLoginManager.toggle()
        updateLaunchAtLoginStatus()
    }

    private func updateLaunchAtLoginStatus() {
        let isEnabled = LaunchAtLoginManager.isEnabled
        launchAtLoginMenuItem?.state = isEnabled ? .on : .off
        print("[AppDelegate] Launch at Login: \(isEnabled ? "Enabled" : "Disabled")")
    }

    private func updatePermissionStatus() {
        let granted = AccessibilityPermission.isGranted()
        if granted {
            permissionMenuItem?.title = "Accessibility: Granted"
            permissionMenuItem?.action = nil  // No action needed when granted
        } else {
            permissionMenuItem?.title = "Accessibility: Not Granted (Click to fix)"
            permissionMenuItem?.action = #selector(openAccessibilitySettings)
        }
        print("[AppDelegate] Permission status: \(granted ? "Granted" : "Not Granted")")

        // Update menu bar icon to reflect permission state
        updateMenuBarIcon(locked: lockManager.isLocked)
    }

    /// Starts polling for permission changes if permission is not yet granted.
    /// Polling interval is 1 second. Stops automatically once permission is granted.
    private func startPermissionPollingIfNeeded() {
        // Don't start polling if permission already granted
        if AccessibilityPermission.isGranted() {
            print("[AppDelegate] Permission already granted, no polling needed")
            return
        }

        print("[AppDelegate] Starting permission polling (1 second interval)")
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if AccessibilityPermission.isGranted() {
                print("[AppDelegate] Permission granted! Stopping polling")
                self.stopPermissionPolling()
                self.updatePermissionStatus()
                // Recreate hotkey monitors now that permission is granted
                self.recreateHotkeyMonitorsIfNeeded()
            }
        }
    }

    /// Recreates the global hotkey monitor if it wasn't created successfully before.
    /// Called when accessibility permission is granted after app launch.
    private func recreateHotkeyMonitorsIfNeeded() {
        // If global monitor is nil, permission wasn't granted when we first tried
        if globalHotkeyMonitor == nil {
            print("[GlobalHotkey] Recreating hotkey monitors after permission granted")
            // Remove any existing monitors first
            if let monitor = localHotkeyMonitor {
                NSEvent.removeMonitor(monitor)
                localHotkeyMonitor = nil
            }
            // Setup fresh monitors
            setupGlobalHotkey()
        }
    }

    /// Stops the permission polling timer.
    private func stopPermissionPolling() {
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = nil
        print("[AppDelegate] Permission polling stopped")
    }

    // MARK: - Sleep/Wake Handling

    /// Sets up observers for system sleep and wake notifications.
    private func setupSleepWakeNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Display sleep/wake notifications (display sleeps while system remains running)
        notificationCenter.addObserver(
            self,
            selector: #selector(handleScreensWillSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleScreensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        // Screen saver notifications (distributed notifications)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenSaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenSaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )

        print("[AppDelegate] Sleep/wake, display sleep/wake, and screen saver notifications registered")
    }

    /// Called when system is about to sleep.
    @objc private func handleSystemWillSleep(_ notification: Notification) {
        print("[AppDelegate] System will sleep - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // No action needed - state persists through sleep
    }

    /// Called when system wakes from sleep.
    @objc private func handleSystemDidWake(_ notification: Notification) {
        print("[AppDelegate] System did wake - lock state: \(lockManager.isLocked)")

        // If locked, reconnect the event tap after wake
        if lockManager.isLocked {
            print("[AppDelegate] Reconnecting event tap after wake")
            lockManager.reconnectEventTapIfNeeded()
        }
    }

    // MARK: - Display Sleep/Wake Handling

    /// Called when displays are about to sleep (but system remains running).
    /// Display sleep is different from system sleep - it happens due to inactivity.
    /// Lock state is preserved - we allow the display to sleep normally.
    @objc private func handleScreensWillSleep(_ notification: Notification) {
        print("[AppDelegate] Displays will sleep - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // Display is allowed to sleep normally - no interference
    }

    /// Called when displays wake from sleep.
    /// Reconnects event tap if needed to ensure input blocking continues.
    @objc private func handleScreensDidWake(_ notification: Notification) {
        print("[AppDelegate] Displays did wake - lock state: \(lockManager.isLocked)")

        // If locked, ensure event tap is still functional after display wake
        if lockManager.isLocked {
            print("[AppDelegate] Reconnecting event tap after display wake")
            lockManager.reconnectEventTapIfNeeded()
        }
    }

    // MARK: - Screen Saver Handling

    /// Called when screen saver starts.
    /// Note: Our overlay uses .screenSaver window level (1000), same as screen savers.
    /// macOS will display the screen saver alongside/over our overlay.
    /// Lock state is preserved - baby lock remains active during screen saver.
    @objc private func handleScreenSaverDidStart(_ notification: Notification) {
        print("[AppDelegate] Screen saver started - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // Screen saver takes precedence visually (both at level 1000, but screen saver is newer window)
        // Input blocking remains active via CGEventTap
    }

    /// Called when screen saver stops.
    /// Reconnects event tap if needed to ensure input blocking continues.
    @objc private func handleScreenSaverDidStop(_ notification: Notification) {
        print("[AppDelegate] Screen saver stopped - lock state: \(lockManager.isLocked)")

        // If locked, ensure event tap is still functional after screen saver dismissal
        if lockManager.isLocked {
            print("[AppDelegate] Reconnecting event tap after screen saver")
            lockManager.reconnectEventTapIfNeeded()
        }
    }

    func updateMenuBarIcon(locked: Bool) {
        guard let button = statusItem?.button else { return }

        let permissionGranted = AccessibilityPermission.isGranted()

        if !permissionGranted && !locked {
            // Show warning state when permission is missing
            // Using lock.trianglebadge.exclamationmark for clear warning indication
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

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] Application terminating - cleaning up resources")

        // Disengage lock state first (stops input interceptor and hides overlay)
        if lockManager.isLocked {
            print("[AppDelegate] Disengaging lock before termination")
            lockManager.disengage()
        }

        // Remove hotkey monitors
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            localHotkeyMonitor = nil
        }
        print("[GlobalHotkey] Hotkey listeners removed")

        // Stop permission polling
        stopPermissionPolling()

        // Remove sleep/wake observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        // Remove screen saver observers
        DistributedNotificationCenter.default().removeObserver(self)
        print("[AppDelegate] Sleep/wake and screen saver observers removed")

        // Release status item
        statusItem = nil
        print("[AppDelegate] All resources released - termination complete")
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update status items each time menu opens
        updatePermissionStatus()
        updateLaunchAtLoginStatus()
    }
}

@main
struct BabyLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
