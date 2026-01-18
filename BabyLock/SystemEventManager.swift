import Foundation
import AppKit

/// Manages system event notifications including sleep/wake, display sleep/wake, and screen saver events.
/// Handles reconnecting the event tap after system state changes to maintain input blocking.
final class SystemEventManager {
    private let lockManager: LockManager

    init(lockManager: LockManager) {
        self.lockManager = lockManager
    }

    /// Sets up observers for all system events.
    func setup() {
        setupSleepWakeNotifications()
        setupDisplayNotifications()
        setupScreenSaverNotifications()
        print("[SystemEventManager] All system event observers registered")
    }

    /// Removes all observers. Call on app termination.
    func cleanup() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        print("[SystemEventManager] All observers removed")
    }

    // MARK: - Sleep/Wake Notifications

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
    }

    @objc private func handleSystemWillSleep(_ notification: Notification) {
        print("[SystemEventManager] System will sleep - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // No action needed - state persists through sleep
    }

    @objc private func handleSystemDidWake(_ notification: Notification) {
        print("[SystemEventManager] System did wake - lock state: \(lockManager.isLocked)")
        reconnectEventTapIfLocked()
    }

    // MARK: - Display Sleep/Wake Notifications

    private func setupDisplayNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

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
    }

    @objc private func handleScreensWillSleep(_ notification: Notification) {
        print("[SystemEventManager] Displays will sleep - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // Display is allowed to sleep normally - no interference
    }

    @objc private func handleScreensDidWake(_ notification: Notification) {
        print("[SystemEventManager] Displays did wake - lock state: \(lockManager.isLocked)")
        reconnectEventTapIfLocked()
    }

    // MARK: - Screen Saver Notifications

    private func setupScreenSaverNotifications() {
        let distributedCenter = DistributedNotificationCenter.default()

        distributedCenter.addObserver(
            self,
            selector: #selector(handleScreenSaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )

        distributedCenter.addObserver(
            self,
            selector: #selector(handleScreenSaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
    }

    @objc private func handleScreenSaverDidStart(_ notification: Notification) {
        print("[SystemEventManager] Screen saver started - lock state preserved: \(lockManager.isLocked)")
        // Lock state is preserved via isLocked property
        // Screen saver takes precedence visually (both at level 1000, but screen saver is newer window)
        // Input blocking remains active via CGEventTap
    }

    @objc private func handleScreenSaverDidStop(_ notification: Notification) {
        print("[SystemEventManager] Screen saver stopped - lock state: \(lockManager.isLocked)")
        reconnectEventTapIfLocked()
    }

    // MARK: - Helpers

    private func reconnectEventTapIfLocked() {
        if lockManager.isLocked {
            print("[SystemEventManager] Reconnecting event tap")
            lockManager.reconnectEventTapIfNeeded()
        }
    }
}
