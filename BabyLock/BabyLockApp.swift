import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    let lockManager = LockManager()
    private var menuBarManager: MenuBarManager?
    private var hotKeyManager: HotKeyManager?
    private var systemEventManager: SystemEventManager?
    private var cancellables = Set<AnyCancellable>()
    private var setupGuidanceController: SetupGuidanceWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var permissionPollingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        handleFirstLaunchIfNeeded()
        setupMenuBar()
        observeLockState()
        setupGlobalHotkey()
        startPermissionPollingIfNeeded()
        setupSystemEventHandling()
        observeShortcutChanges()
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

    private func observeShortcutChanges() {
        NotificationCenter.default.addObserver(
            forName: .shortcutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBarManager?.updateShortcutDisplay()
        }
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

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow()
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

    // MARK: - System Event Handling

    private func setupSystemEventHandling() {
        systemEventManager = SystemEventManager(lockManager: lockManager)
        systemEventManager?.setup()
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

        // Remove system event observers
        systemEventManager?.cleanup()
        systemEventManager = nil

        // Release menu bar manager
        menuBarManager?.cleanup()
        menuBarManager = nil

        // Clean up settings window
        settingsWindowController = nil

        print("[AppDelegate] All resources released - termination complete")
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update status items each time menu opens
        menuBarManager?.updatePermissionStatus()
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
