import Foundation
import CoreGraphics

/// Intercepts system-wide keyboard and mouse input using CGEventTap.
/// Used to block all input when the app is in locked state.
class InputInterceptor {
    /// Shared instance for access from static callback
    private static var current: InputInterceptor?

    /// Callback triggered when unlock hotkey (Cmd+Shift+B) is pressed while locked
    var onUnlockHotkey: (() -> Void)?

    /// Callback triggered when any key is pressed (for visual feedback)
    var onKeyPressed: ((String) -> Void)?

    /// The CGEventTap for intercepting input events
    private var eventTap: CFMachPort?

    /// The run loop source for integrating the event tap with the run loop
    private var runLoopSource: CFRunLoopSource?

    /// Starts the input interception by creating and enabling the event tap.
    /// Requires Accessibility permission to function.
    func start() {
        // Check accessibility permission first
        guard AccessibilityPermission.isGranted() else {
            print("[InputInterceptor] Cannot start - Accessibility permission not granted")
            return
        }

        // Define event mask for all input events we want to intercept
        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.keyDown.rawValue)
        eventMask |= (1 << CGEventType.keyUp.rawValue)
        eventMask |= (1 << CGEventType.flagsChanged.rawValue)
        eventMask |= (1 << CGEventType.mouseMoved.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.leftMouseUp.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDown.rawValue)
        eventMask |= (1 << CGEventType.rightMouseUp.rawValue)
        eventMask |= (1 << CGEventType.scrollWheel.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDragged.rawValue)

        // Create the event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: InputInterceptor.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("[InputInterceptor] Failed to create event tap - check accessibility permissions")
            return
        }

        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)

        // Store reference for static callback access
        InputInterceptor.current = self

        print("[InputInterceptor] Event tap started - input interception active")
    }

    /// Stops the input interception by disabling and removing the event tap.
    func stop() {
        // Clear static reference
        InputInterceptor.current = nil

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        print("[InputInterceptor] Event tap stopped - input interception disabled")
    }

    /// Re-enables the event tap if it was disabled by the system.
    fileprivate func reEnableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[InputInterceptor] Re-enabled event tap after system disabled it")
        }
    }

    /// Reconnects the event tap after system wake.
    /// Stops and restarts the tap to ensure proper functioning after wake.
    func reconnect() {
        // Check if event tap is still valid
        if let tap = eventTap {
            // Try to re-enable first
            CGEvent.tapEnable(tap: tap, enable: true)

            // Verify tap is enabled
            if CGEvent.tapIsEnabled(tap: tap) {
                print("[InputInterceptor] Event tap re-enabled successfully after wake")
                return
            }
        }

        // If tap is nil or couldn't be re-enabled, recreate it
        print("[InputInterceptor] Recreating event tap after wake")
        stop()
        start()
    }

    /// Static callback function for the CGEventTap.
    /// This is called for every intercepted event.
    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        // Handle tap timeout/disable - re-enable the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon = refcon {
                let interceptor = Unmanaged<InputInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                interceptor.reEnableEventTap()
            }
            return Unmanaged.passUnretained(event)
        }

        // Check for unlock hotkey (configurable shortcut)
        if type == .keyDown {
            let shortcut = ShortcutConfigurationManager.shared.currentShortcut
            if shortcut.matches(cgEvent: event) {
                print("[InputInterceptor] Unlock hotkey detected (\(shortcut.displayString))!")
                // Trigger unlock callback on main thread
                DispatchQueue.main.async {
                    InputInterceptor.current?.onUnlockHotkey?()
                }
                // Block the event (don't pass to other apps)
                return nil
            }

            // Extract character for visual feedback (only for regular keys without Cmd)
            let flags = event.flags
            if !flags.contains(.maskCommand) {
                if let character = getCharacterFromEvent(event) {
                    DispatchQueue.main.async {
                        InputInterceptor.current?.onKeyPressed?(character)
                    }
                }
            }
        }

        // Block all other events by returning nil
        return nil
    }

    /// Extracts the typed character from a CGEvent
    private static func getCharacterFromEvent(_ event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)

        guard length > 0 else { return nil }

        let string = String(utf16CodeUnits: chars, count: length)

        // Filter out control characters but allow letters, numbers, symbols
        guard let scalar = string.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else {
            return nil
        }

        return string
    }
}
