import Foundation
import Combine

/// Manages the lock state for Baby Lock application.
/// Coordinates between input interception and visual overlay.
class LockManager: ObservableObject {
    /// Current lock state - true when input is blocked
    @Published var isLocked: Bool = false

    /// Input interceptor for blocking keyboard and mouse input
    private let inputInterceptor = InputInterceptor()

    /// Overlay window showing blue glow border when locked
    private let overlayWindow = OverlayWindow()

    /// Flag to prevent rapid toggle operations during state transitions
    private var isTransitioning: Bool = false

    /// Minimum time between toggle operations to prevent rapid toggling
    private let toggleDebounceInterval: TimeInterval = 0.35

    /// Timestamp of last toggle operation
    private var lastToggleTime: Date = .distantPast

    init() {
        // Set up unlock hotkey callback - triggered by InputInterceptor when Cmd+Shift+B pressed while locked
        inputInterceptor.onUnlockHotkey = { [weak self] in
            print("[LockManager] Unlock hotkey received from InputInterceptor")
            self?.disengage()
        }
    }

    /// Toggles the lock state between locked and unlocked.
    /// Protected against rapid toggling to prevent crashes and visual glitches.
    /// - Returns: The new lock state after toggling
    @discardableResult
    func toggle() -> Bool {
        print("[LockManager] toggle() called - current state: \(isLocked ? "LOCKED" : "UNLOCKED")")

        // Debounce rapid toggle attempts
        let now = Date()
        let timeSinceLastToggle = now.timeIntervalSince(lastToggleTime)
        guard timeSinceLastToggle >= toggleDebounceInterval else {
            print("[LockManager] Toggle debounced - only \(String(format: "%.2f", timeSinceLastToggle))s since last toggle (need \(toggleDebounceInterval)s)")
            return isLocked
        }

        // Prevent overlapping transitions
        guard !isTransitioning else {
            print("[LockManager] Toggle blocked - transition in progress")
            return isLocked
        }

        if isLocked {
            disengage()
        } else {
            engage()
        }
        return isLocked
    }

    /// Engages the lock - blocks input and shows overlay.
    /// Called when transitioning from unlocked to locked state.
    func engage() {
        guard !isLocked else { return }
        guard !isTransitioning else {
            print("[LockManager] Engage blocked - transition in progress")
            return
        }

        isTransitioning = true
        lastToggleTime = Date()
        isLocked = true
        print("[LockManager] State changed: LOCKED")

        // Start input interceptor to block all input
        inputInterceptor.start()

        // Show overlay window with blue glow border
        overlayWindow.show { [weak self] in
            self?.isTransitioning = false
        }
    }

    /// Disengages the lock - restores input and hides overlay.
    /// Called when transitioning from locked to unlocked state.
    func disengage() {
        guard isLocked else { return }
        guard !isTransitioning else {
            print("[LockManager] Disengage blocked - transition in progress")
            return
        }

        isTransitioning = true
        lastToggleTime = Date()
        isLocked = false
        print("[LockManager] State changed: UNLOCKED")

        // Stop input interceptor to restore input
        inputInterceptor.stop()

        // Hide overlay window
        overlayWindow.hide { [weak self] in
            self?.isTransitioning = false
        }
    }

    /// Reconnects the event tap after system wake if needed.
    /// Called when system wakes and lock was engaged.
    func reconnectEventTapIfNeeded() {
        guard isLocked else {
            print("[LockManager] Not locked, no need to reconnect event tap")
            return
        }

        print("[LockManager] Reconnecting event tap after wake")
        inputInterceptor.reconnect()
    }
}
