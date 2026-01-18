import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    let lockManager = LockManager()
    private var menuBarManager: MenuBarManager?
    private var hotKeyManager: HotKeyManager?
    private var cancellables = Set<AnyCancellable>()
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
        menuBarManager = MenuBarManager(delegate: self)
        menuBarManager?.setup()
    }

    private func observeLockState() {
        lockManager.$isLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                self?.menuBarManager?.updateIcon(locked: isLocked)
            }
            .store(in: &cancellables)
    }

    private func setupGlobalHotkey() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.lockManager.toggle()
        }
        hotKeyManager?.setup()
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
        menuBarManager?.updateLaunchAtLoginStatus()
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
                self.menuBarManager?.updatePermissionStatus()
                // Recreate hotkey monitors now that permission is granted
                self.recreateHotkeyMonitorsIfNeeded()
            }
        }
    }

    /// Recreates the global hotkey monitor when permission is granted.
    /// Called when accessibility permission is granted after app launch.
    private func recreateHotkeyMonitorsIfNeeded() {
        hotKeyManager?.recreateMonitors()
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

    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] Application terminating - cleaning up resources")

        // Disengage lock state first (stops input interceptor and hides overlay)
        if lockManager.isLocked {
            print("[AppDelegate] Disengaging lock before termination")
            lockManager.disengage()
        }

        // Remove hotkey monitors
        hotKeyManager?.cleanup()
        hotKeyManager = nil

        // Stop permission polling
        stopPermissionPolling()

        // Remove sleep/wake observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)

        // Remove screen saver observers
        DistributedNotificationCenter.default().removeObserver(self)
        print("[AppDelegate] Sleep/wake and screen saver observers removed")

        // Release menu bar manager
        menuBarManager?.cleanup()
        menuBarManager = nil
        print("[AppDelegate] All resources released - termination complete")
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update status items each time menu opens
        menuBarManager?.updatePermissionStatus()
        menuBarManager?.updateLaunchAtLoginStatus()
    }
}

// MARK: - MenuBarManagerDelegate
extension AppDelegate: MenuBarManagerDelegate {
    var isLocked: Bool {
        lockManager.isLocked
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
