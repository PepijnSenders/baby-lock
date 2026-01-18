# 01: Input Interception

**Layer 1** - System-level input capture using CGEventTap to block all keyboard and mouse input.

## Overview

The input interception layer handles:
- Creating a CGEventTap to intercept all input events
- Blocking keyboard, mouse movement, clicks, and trackpad
- Allowing the unlock hotkey (Cmd+Shift+B) to pass through
- Clean start/stop of event tap

## Dependencies

- **Layer 0**: Core App (for lock state management)

## CGEventTap Architecture

```
+------------------------------------------------------------------+
|                     macOS Event System                             |
+------------------------------------------------------------------+
|                                                                    |
|   Hardware    CGEventTap     baby-lock      App Event              |
|   Events  --> (intercept) --> Filter --> Queues (blocked)          |
|                   |                                                |
|                   v                                                |
|              Return NULL                                           |
|              (event eaten)                                         |
|                                                                    |
|   EXCEPTION: Cmd+Shift+B passes through to toggle lock             |
|                                                                    |
+------------------------------------------------------------------+
```

## Event Types to Block

| Event Type | CGEventType | Block? |
|------------|-------------|--------|
| Key down | kCGEventKeyDown | Yes |
| Key up | kCGEventKeyUp | Yes |
| Modifier change | kCGEventFlagsChanged | Yes |
| Mouse move | kCGEventMouseMoved | Yes |
| Left click down | kCGEventLeftMouseDown | Yes |
| Left click up | kCGEventLeftMouseUp | Yes |
| Right click down | kCGEventRightMouseDown | Yes |
| Right click up | kCGEventRightMouseUp | Yes |
| Scroll wheel | kCGEventScrollWheel | Yes |
| Other mouse | kCGEventOtherMouse* | Yes |

## CGEventTap Implementation

### Creating the Event Tap

```swift
import Cocoa
import CoreGraphics

class InputInterceptor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue)
        )

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap - check accessibility permissions")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
```

### Event Tap Callback

```swift
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Handle special case: system disabled the tap (timeout)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let interceptor = Unmanaged<InputInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = interceptor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Check for unlock hotkey: Cmd+Shift+B
    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // B key = 11, check for Cmd+Shift
        if keyCode == 11 &&
           flags.contains(.maskCommand) &&
           flags.contains(.maskShift) {
            // Let this event through - it will trigger unlock
            return Unmanaged.passUnretained(event)
        }
    }

    // Block all other events by returning nil
    return nil
}
```

## Handling Event Tap Timeout

macOS will disable event taps that take too long to process. Handle this:

```swift
// In callback, check for disable events
if type == .tapDisabledByTimeout {
    // Re-enable the tap
    CGEvent.tapEnable(tap: eventTap, enable: true)
    return Unmanaged.passUnretained(event)
}
```

## Permissions

### Accessibility Permission Required

CGEventTap requires Accessibility permission:

```swift
func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
```

### Prompting User

```swift
func requestAccessibility() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Baby Lock needs Accessibility access to block input. Please enable it in System Preferences > Security & Privacy > Privacy > Accessibility."
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
```

## Edge Cases

### Force Quit Still Works

- Cmd+Option+Esc (Force Quit) is handled by WindowServer before CGEventTap
- This is a safety feature - user can always force quit
- Consider: should we try to block this? (Probably not - safety valve)

### Touch Bar (if present)

- Touch Bar is separate from CGEventTap
- May need additional handling on MacBooks with Touch Bar

### External Keyboards/Mice

- CGEventTap intercepts ALL input devices
- Bluetooth and USB devices are all captured

## Acceptance Criteria

### MVP Requirements

1. [ ] CGEventTap successfully created when lock engaged
2. [ ] All keyboard input blocked (except Cmd+Shift+B)
3. [ ] All mouse/trackpad input blocked
4. [ ] Event tap cleanly stopped when unlocked
5. [ ] Handles accessibility permission gracefully

### Post-MVP Requirements

1. [ ] Optional: allow mouse movement but block clicks
2. [ ] Handle Touch Bar input
3. [ ] Re-enable tap if system disables it
