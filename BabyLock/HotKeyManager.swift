import AppKit

/// Manages global and local hotkey monitoring for the Cmd+Shift+B keyboard shortcut.
/// Handles monitor creation, permission-aware recreation, and cleanup.
final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onHotkeyPressed: () -> Void

    /// Creates a new HotKeyManager with the specified hotkey action.
    /// - Parameter onHotkeyPressed: Closure called when Cmd+Shift+B is pressed.
    init(onHotkeyPressed: @escaping () -> Void) {
        self.onHotkeyPressed = onHotkeyPressed
    }

    /// Sets up both global and local hotkey monitors.
    /// Global monitor catches hotkey when other apps have focus (requires Accessibility permission).
    /// Local monitor catches hotkey when BabyLock itself has focus.
    func setup() {
        let hotkeyHandler: (NSEvent) -> Void = { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Global monitor: catches hotkey when OTHER apps have focus
        // Requires Accessibility permission
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: hotkeyHandler)

        if globalMonitor == nil {
            print("[HotKeyManager] WARNING: Failed to create global monitor - Accessibility permission may be missing")
        } else {
            // Monitor object created, but verify permission is actually granted
            // (macOS can return non-nil even without permission, but events won't be delivered)
            if AccessibilityPermission.isGranted() {
                print("[HotKeyManager] Global monitor created and permission granted - hotkey will work")
            } else {
                print("[HotKeyManager] Global monitor created but permission NOT granted - hotkey will NOT work until permission is granted")
            }
        }

        // Local monitor: catches hotkey when BabyLock itself has focus (e.g., menu open)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            hotkeyHandler(event)
            return event  // Pass event through
        }

        if localMonitor == nil {
            print("[HotKeyManager] WARNING: Failed to create local monitor")
        } else {
            print("[HotKeyManager] Local monitor created successfully")
        }

        print("[HotKeyManager] Hotkey setup complete")
    }

    /// Recreates hotkey monitors after accessibility permission is granted.
    /// Always recreates monitors because they may be non-functional even if non-nil
    /// (macOS returns non-nil monitor objects even without permission, but events won't be delivered).
    func recreateMonitors() {
        print("[HotKeyManager] Recreating hotkey monitors after permission granted")
        cleanup()
        setup()
    }

    /// Removes all hotkey monitors and releases resources.
    func cleanup() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        print("[HotKeyManager] Hotkey monitors removed")
    }

    // MARK: - Private

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for keyCode 11 (B key) with Command and Shift modifiers
        // Use rawValue check to ensure we're detecting the correct key combination
        let flags = event.modifierFlags

        if event.keyCode == 11 &&
           flags.contains(.command) &&
           flags.contains(.shift) &&
           !flags.contains(.control) &&
           !flags.contains(.option) {
            print("[HotKeyManager] Cmd+Shift+B detected (keyCode: \(event.keyCode), flags: \(flags.rawValue))")
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyPressed()
            }
        }
    }
}
