import Foundation
import AppKit

/// Manages system event notifications including sleep/wake, display sleep/wake, and screen saver events.
/// Handles reconnecting the event tap after system state changes to maintain input blocking.
final class SystemEventManager {
    private let lockManager: LockManager

    /// Defines how to handle a system event
    private enum EventAction {
        case preserveState(description: String)
        case reconnectTap(description: String)
    }

    /// Configuration for a system event observer
    private struct EventConfig {
        let name: Notification.Name
        let action: EventAction
        let useDistributedCenter: Bool

        init(_ name: Notification.Name, action: EventAction, distributed: Bool = false) {
            self.name = name
            self.action = action
            self.useDistributedCenter = distributed
        }
    }

    /// All system events to observe
    private let eventConfigs: [EventConfig] = [
        // Sleep/Wake
        EventConfig(NSWorkspace.willSleepNotification,
                    action: .preserveState(description: "System will sleep")),
        EventConfig(NSWorkspace.didWakeNotification,
                    action: .reconnectTap(description: "System did wake")),
        // Display Sleep/Wake
        EventConfig(NSWorkspace.screensDidSleepNotification,
                    action: .preserveState(description: "Displays will sleep")),
        EventConfig(NSWorkspace.screensDidWakeNotification,
                    action: .reconnectTap(description: "Displays did wake")),
        // Screen Saver
        EventConfig(Notification.Name("com.apple.screensaver.didstart"),
                    action: .preserveState(description: "Screen saver started"),
                    distributed: true),
        EventConfig(Notification.Name("com.apple.screensaver.didstop"),
                    action: .reconnectTap(description: "Screen saver stopped"),
                    distributed: true),
    ]

    init(lockManager: LockManager) {
        self.lockManager = lockManager
    }

    /// Sets up observers for all system events.
    func setup() {
        for config in eventConfigs {
            let center: Any = config.useDistributedCenter
                ? DistributedNotificationCenter.default()
                : NSWorkspace.shared.notificationCenter

            if let workspaceCenter = center as? NotificationCenter {
                workspaceCenter.addObserver(
                    self,
                    selector: #selector(handleSystemEvent),
                    name: config.name,
                    object: nil
                )
            } else if let distributedCenter = center as? DistributedNotificationCenter {
                distributedCenter.addObserver(
                    self,
                    selector: #selector(handleSystemEvent),
                    name: config.name,
                    object: nil
                )
            }
        }
        print("[SystemEventManager] All system event observers registered")
    }

    /// Removes all observers. Call on app termination.
    func cleanup() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        print("[SystemEventManager] All observers removed")
    }

    // MARK: - Unified Event Handler

    @objc private func handleSystemEvent(_ notification: Notification) {
        guard let config = eventConfigs.first(where: { $0.name == notification.name }) else {
            return
        }

        switch config.action {
        case .preserveState(let description):
            print("[SystemEventManager] \(description) - lock state preserved: \(lockManager.isLocked)")

        case .reconnectTap(let description):
            print("[SystemEventManager] \(description) - lock state: \(lockManager.isLocked)")
            if lockManager.isLocked {
                print("[SystemEventManager] Reconnecting event tap")
                lockManager.reconnectEventTapIfNeeded()
            }
        }
    }
}
