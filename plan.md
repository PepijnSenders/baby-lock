# baby-lock Implementation Plan

## Overview

MVP implementation plan for baby-lock - a native macOS menu bar app that blocks all keyboard and mouse input with a visual indicator, designed to let babies watch the screen safely.

**Goal**: Working app that can be activated via Cmd+Shift+B to lock all input while showing a soft blue glow border.

---

## Phase 1: Core App Foundation

> **Spec**: [specs/v1/00-core-app.md](./specs/v1/00-core-app.md)

### 1.1 Project Setup

- [x] **Create Xcode project**
  - AC: New macOS App project created with SwiftUI lifecycle
  - AC: Bundle identifier set to `com.babylock.app`
  - AC: Deployment target set to macOS 12.0+
  - AC: Project builds with no errors

- [x] **Configure as menu bar app**
  - AC: `LSUIElement` set to `true` in Info.plist
  - AC: App does not appear in Dock when running
  - AC: App does not appear in Cmd+Tab switcher
  - AC: Only menu bar icon visible

- [x] **Set up app entry point**
  - AC: `@main` struct uses `@NSApplicationDelegateAdaptor`
  - AC: `body` contains empty `Settings` scene (menu bar only)
  - AC: App launches without windows

### 1.2 Menu Bar Implementation

- [x] **Create status item**
  - AC: `NSStatusItem` created with variable length
  - AC: Status item appears in menu bar on launch
  - AC: Status item persists while app runs

- [x] **Implement menu bar icon**
  - AC: Uses SF Symbol `lock.open` for unlocked state
  - AC: Uses SF Symbol `lock.fill` for locked state
  - AC: Icon renders correctly in light and dark mode
  - AC: Icon has accessibility description "Baby Lock"

- [x] **Create menu bar dropdown**
  - AC: Menu appears on click
  - AC: "Toggle Lock (Cmd+Shift+B)" menu item present
  - AC: Separator line between toggle and quit
  - AC: "Quit" menu item present with "q" key equivalent
  - AC: Toggle menu item triggers lock state change
  - AC: Quit menu item terminates app cleanly

### 1.3 Lock State Management

- [x] **Implement LockManager class**
  - AC: `LockManager` is `ObservableObject`
  - AC: `@Published var isLocked: Bool` tracks state
  - AC: Initial state is `false` (unlocked)

- [x] **Implement toggle function**
  - AC: `toggle()` flips `isLocked` boolean
  - AC: Logs state change to console for debugging
  - AC: Returns new state value

- [x] **Wire up engage/disengage**
  - AC: `engage()` called when transitioning to locked
  - AC: `disengage()` called when transitioning to unlocked
  - AC: Functions are empty stubs for now (will wire to overlay/input later)

- [x] **Update menu bar icon on state change**
  - AC: Icon changes to `lock.fill` when locked
  - AC: Icon changes to `lock.open` when unlocked
  - AC: Icon updates immediately on toggle

### 1.4 Global Hotkey Registration

- [x] **Research hotkey implementation approach**
  - AC: Document Carbon Events vs NSEvent.addGlobalMonitorForEvents
  - AC: Choose approach that works when app is not frontmost
  - AC: Verify approach works with accessibility permission

- [x] **Implement global hotkey listener**
  - AC: Listens for Cmd+Shift+B (keyCode 11 with command+shift modifiers)
  - AC: Works when any app is focused (global)
  - AC: Does not interfere with other apps using same shortcut

- [x] **Connect hotkey to toggle**
  - AC: Pressing Cmd+Shift+B calls `LockManager.toggle()`
  - AC: Hotkey works in both locked and unlocked states
  - AC: Menu bar icon updates when toggled via hotkey

### 1.5 Phase 1 Milestone Verification

- [x] **End-to-end test: core app**
  - AC: App launches with menu bar icon only (no dock, no window)
  - AC: Menu bar icon shows `lock.open` initially
  - AC: Clicking menu shows dropdown with toggle and quit
  - AC: Pressing Cmd+Shift+B changes icon to `lock.fill`
  - AC: Pressing Cmd+Shift+B again changes icon back to `lock.open`
  - AC: Clicking "Quit" terminates the app
  - AC: No zombie processes after quit

---

## Phase 2: Input Interception

> **Spec**: [specs/v1/01-input-interception.md](./specs/v1/01-input-interception.md)

### 2.1 Accessibility Permission Check

- [x] **Implement permission check function**
  - AC: `AXIsProcessTrusted()` called to check permission
  - AC: Returns `true` if permission granted
  - AC: Returns `false` if permission not granted

- [x] **Implement permission request**
  - AC: `AXIsProcessTrustedWithOptions` with prompt option
  - AC: System dialog appears asking for accessibility permission
  - AC: Links to correct System Preferences pane

- [x] **Handle permission not granted**
  - AC: Alert shown explaining why permission is needed
  - AC: "Open System Preferences" button opens Accessibility pane
  - AC: App continues running but lock feature disabled
  - AC: Clear status indication in menu when permission missing

### 2.2 CGEventTap Setup

- [x] **Implement InputInterceptor class**
  - AC: Class manages `CFMachPort?` event tap
  - AC: Class manages `CFRunLoopSource?` for run loop integration
  - AC: Class has `start()` and `stop()` methods

- [x] **Create event tap with correct mask**
  - AC: Event mask includes `keyDown`
  - AC: Event mask includes `keyUp`
  - AC: Event mask includes `flagsChanged`
  - AC: Event mask includes `mouseMoved`
  - AC: Event mask includes `leftMouseDown` and `leftMouseUp`
  - AC: Event mask includes `rightMouseDown` and `rightMouseUp`
  - AC: Event mask includes `scrollWheel`
  - AC: Event mask includes `leftMouseDragged` and `rightMouseDragged`

- [x] **Configure event tap placement**
  - AC: Uses `.cgSessionEventTap` for session-level capture
  - AC: Uses `.headInsertEventTap` for early interception
  - AC: Uses `.defaultTap` option (can modify events)

- [x] **Add event tap to run loop**
  - AC: `CFMachPortCreateRunLoopSource` creates run loop source
  - AC: `CFRunLoopAddSource` adds to current run loop
  - AC: Uses `.commonModes` for consistent execution
  - AC: `CGEvent.tapEnable` enables the tap

### 2.3 Event Filtering

- [x] **Implement event tap callback**
  - AC: Callback receives event proxy, type, event, and refcon
  - AC: Returns `Unmanaged<CGEvent>?` (nil to block, event to pass)
  - AC: Has access to InputInterceptor instance via refcon

- [x] **Block all input events**
  - AC: Keyboard events return `nil` (blocked)
  - AC: Mouse events return `nil` (blocked)
  - AC: Trackpad events return `nil` (blocked)
  - AC: Scroll events return `nil` (blocked)

- [x] **Allow unlock hotkey to pass through**
  - AC: Detects keyCode 11 (B key) with Cmd+Shift modifiers
  - AC: Returns event (not nil) for Cmd+Shift+B
  - AC: Unlock hotkey triggers toggle even when locked

- [x] **Handle event tap timeout**
  - AC: Detects `.tapDisabledByTimeout` event type
  - AC: Re-enables tap via `CGEvent.tapEnable`
  - AC: Logs warning when timeout occurs
  - AC: Tap continues working after re-enable

### 2.4 Start/Stop Control

- [x] **Implement start function**
  - AC: Checks accessibility permission first
  - AC: Creates event tap only if permission granted
  - AC: Logs error if event tap creation fails
  - AC: Sets up run loop source and enables tap
  - AC: Stores references for later cleanup

- [x] **Implement stop function**
  - AC: Disables event tap via `CGEvent.tapEnable(enable: false)`
  - AC: Removes run loop source via `CFRunLoopRemoveSource`
  - AC: Sets `eventTap` and `runLoopSource` to nil
  - AC: Safe to call multiple times (idempotent)

- [x] **Wire to LockManager**
  - AC: `LockManager.engage()` calls `inputInterceptor.start()`
  - AC: `LockManager.disengage()` calls `inputInterceptor.stop()`
  - AC: Input blocking activates immediately on lock
  - AC: Input restored immediately on unlock

### 2.5 Phase 2 Milestone Verification

- [x] **End-to-end test: input blocking**
  - AC: With permission granted, Cmd+Shift+B activates lock
  - AC: All keyboard input blocked (try typing in any app)
  - AC: All mouse clicks blocked (try clicking anywhere)
  - AC: Mouse cursor still visible (cursor doesn't hide)
  - AC: Trackpad gestures blocked (swipe, scroll)
  - AC: Cmd+Shift+B still works to unlock
  - AC: After unlock, all input works normally
  - AC: Force Quit (Cmd+Option+Esc) still works (safety valve)

---

## Phase 3: Visual Overlay

> **Spec**: [specs/v1/02-visual-overlay.md](./specs/v1/02-visual-overlay.md)

### 3.1 Overlay Window Setup

- [x] **Create OverlayWindow class**
  - AC: Subclasses `NSWindow`
  - AC: Custom initializer sets up window properties
  - AC: Window frame matches main screen frame

- [x] **Configure window style**
  - AC: `styleMask` is `.borderless` (no title bar)
  - AC: `backing` is `.buffered`
  - AC: `defer` is `false`

- [x] **Configure window level**
  - AC: `level` set to `.screenSaver` (above everything)
  - AC: Window appears over fullscreen apps
  - AC: Window appears over dock and menu bar

- [x] **Configure transparency**
  - AC: `backgroundColor` is `.clear`
  - AC: `isOpaque` is `false`
  - AC: `hasShadow` is `false`
  - AC: Center of window is see-through

- [x] **Configure click-through**
  - AC: `ignoresMouseEvents` is `true`
  - AC: Window never intercepts clicks
  - AC: Input interceptor handles blocking, not window

- [x] **Configure collection behavior**
  - AC: `.canJoinAllSpaces` - shows on all desktops
  - AC: `.fullScreenAuxiliary` - works with fullscreen apps
  - AC: `.stationary` - doesn't move with space switches

### 3.2 Blue Glow Border

- [x] **Define glow color**
  - AC: Soft blue color: RGB(0.3, 0.6, 1.0)
  - AC: Color visible in both light and dark environments
  - AC: Not too bright to be distracting

- [x] **Implement glow border view (SwiftUI)**
  - AC: Uses `GeometryReader` for full-frame layout
  - AC: Transparent `Color.clear` in center
  - AC: `RoundedRectangle` stroke with blur for outer glow
  - AC: Sharper inner edge stroke for definition
  - AC: Glow width approximately 40pt
  - AC: Blur radius approximately 20pt

- [x] **Alternative: Implement glow border view (AppKit)**
  - AC: Custom `NSView` subclass if SwiftUI has issues
  - AC: Uses Core Graphics for drawing
  - AC: `CGContext.setShadow` for glow effect
  - AC: Draws stroked rectangle path

- [x] **Host view in window**
  - AC: SwiftUI view wrapped in `NSHostingView`
  - AC: View fills entire window content
  - AC: View respects `.ignoresSafeArea()`

### 3.3 Animation

- [x] **Implement fade-in animation**
  - AC: Window starts with `alphaValue = 0`
  - AC: `orderFrontRegardless()` shows window
  - AC: `NSAnimationContext` animates to `alphaValue = 1`
  - AC: Animation duration is 0.3 seconds
  - AC: Smooth ease-in-out curve

- [x] **Implement fade-out animation**
  - AC: `NSAnimationContext` animates to `alphaValue = 0`
  - AC: Animation duration is 0.2 seconds
  - AC: `orderOut(nil)` called in completion handler
  - AC: Window hidden only after animation completes

- [x] **Wire to LockManager**
  - AC: `LockManager.engage()` calls `overlayWindow.show()`
  - AC: `LockManager.disengage()` calls `overlayWindow.hide()`
  - AC: Overlay visible immediately on lock
  - AC: Overlay fades out on unlock

### 3.4 Screen Handling

- [x] **Get main screen bounds**
  - AC: Uses `NSScreen.main?.frame`
  - AC: Handles nil screen gracefully
  - AC: Window frame matches screen exactly

- [x] **Handle screen resolution changes**
  - AC: Observe `NSApplication.didChangeScreenParametersNotification`
  - AC: Update window frame when screen changes
  - AC: Works when external monitor connected/disconnected

### 3.5 Phase 3 Milestone Verification

- [x] **End-to-end test: visual overlay**
  - AC: Cmd+Shift+B shows blue glow border
  - AC: Desktop/apps visible through transparent center
  - AC: Glow visible around all screen edges
  - AC: Window appears over fullscreen video
  - AC: Window appears on correct (main) monitor
  - AC: Smooth fade-in when locking
  - AC: Smooth fade-out when unlocking
  - AC: No visual artifacts or glitches

---

## Phase 4: System Integration

> **Spec**: [specs/v1/03-system-integration.md](./specs/v1/03-system-integration.md)

### 4.1 Launch at Login

- [x] **Implement LaunchAtLoginManager (macOS 13+)**
  - AC: Uses `SMAppService.mainApp`
  - AC: `register()` enables launch at login
  - AC: `unregister()` disables launch at login
  - AC: `status == .enabled` checks current state

- [x] **Add menu item for launch at login**
  - AC: "Launch at Login" checkbox menu item added
  - AC: Checkmark reflects current state
  - AC: Clicking toggles the setting
  - AC: State persists across app restarts

- [x] **Handle registration errors**
  - AC: Catches errors from `register()`/`unregister()`
  - AC: Logs errors to console
  - AC: Shows alert if registration fails
  - AC: App continues working even if login item fails

### 4.2 First Launch Experience

- [x] **Detect first launch**
  - AC: Check `UserDefaults` for `hasLaunchedBefore` key
  - AC: First launch when key is false or missing
  - AC: Set key to true after first launch handling

- [x] **Request accessibility permission on first launch**
  - AC: `AXIsProcessTrustedWithOptions` called with prompt
  - AC: System permission dialog appears
  - AC: User guided to enable permission

- [x] **Show setup guidance**
  - AC: Brief explanation of what app does
  - AC: Explanation of Cmd+Shift+B hotkey
  - AC: Explanation of why accessibility permission needed
  - AC: Can be dismissed and not shown again

### 4.3 Permission Status Display

- [x] **Show permission status in menu**
  - AC: Menu shows "Accessibility: Granted" or "Accessibility: Not Granted"
  - AC: Status updates dynamically
  - AC: Click opens System Preferences if not granted

- [x] **Poll for permission changes**
  - AC: Timer checks `AXIsProcessTrusted()` periodically
  - AC: Polling interval is 1 second
  - AC: Stop polling once permission granted
  - AC: Update UI when permission changes

### 4.4 App Configuration

- [x] **Configure Info.plist**
  - AC: `LSUIElement` is `true` (menu bar app)
  - AC: `LSMinimumSystemVersion` is `12.0`
  - AC: `NSHumanReadableCopyright` set
  - AC: Bundle display name is "Baby Lock"

- [x] **Configure entitlements (non-sandboxed)**
  - AC: `com.apple.security.app-sandbox` is `false`
  - AC: App can use CGEventTap without sandbox restrictions
  - AC: App can use SMAppService for login items

### 4.5 Clean Shutdown

- [x] **Handle app termination**
  - AC: Stop input interceptor before quit
  - AC: Hide overlay window before quit
  - AC: Release all resources cleanly
  - AC: No zombie processes

- [x] **Handle unexpected termination**
  - AC: If app crashes while locked, input restored (CGEventTap dies with process)
  - AC: No persistent lock state (starts unlocked on relaunch)

### 4.6 Phase 4 Milestone Verification

- [x] **End-to-end test: system integration**
  - AC: App starts on login (when enabled)
  - AC: First launch shows permission request
  - AC: Menu shows accessibility permission status
  - AC: Launch at Login toggle works
  - AC: App quits cleanly (no locked state left behind)
  - AC: App recovers cleanly after force quit

---

## Phase 5: Polish & Edge Cases

### 5.1 Robustness

- [x] **Handle rapid toggle**
  - AC: Fast Cmd+Shift+B presses don't crash
  - AC: State remains consistent
  - AC: No visual glitches from rapid animation

- [x] **Handle sleep/wake**
  - AC: App survives system sleep
  - AC: Lock state preserved after wake
  - AC: Event tap reconnects after wake if needed

- [x] **Handle screen saver activation**
  - AC: Screen saver can still activate (not blocked by overlay level)
  - AC: OR: Screen saver blocked (overlay takes precedence) - document behavior
  - AC: Lock state preserved when screen saver dismisses

- [x] **Handle display sleep**
  - AC: Display can still sleep
  - AC: Lock state preserved when display wakes

### 5.2 User Experience Polish

- [x] **Add menu bar tooltip**
  - AC: Hovering menu bar icon shows "Baby Lock"
  - AC: Tooltip shows current state (Locked/Unlocked)

- [x] **Add visual feedback for permission missing**
  - AC: Menu bar icon shows warning state if no permission
  - AC: OR: Badge/overlay on icon indicating issue

- [x] **Optimize overlay performance**
  - AC: Overlay uses minimal CPU when displayed
  - AC: No perceptible lag when locking/unlocking
  - AC: Animation is 60fps smooth

### 5.3 Testing Checklist

- [x] **Test on different macOS versions**
  - AC: Works on macOS 12 (Monterey)
  - AC: Works on macOS 13 (Ventura)
  - AC: Works on macOS 14 (Sonoma)
  - AC: Works on macOS 15 (Sequoia)

- [ ] **Test with different displays**
  - AC: Works on built-in Retina display
  - AC: Works on external 4K display
  - AC: Works on external 1080p display
  - AC: Correct behavior with multiple monitors (main only)

- [ ] **Test with different input devices**
  - AC: Blocks built-in keyboard
  - AC: Blocks USB keyboard
  - AC: Blocks Bluetooth keyboard
  - AC: Blocks built-in trackpad
  - AC: Blocks USB mouse
  - AC: Blocks Bluetooth mouse

### 5.4 Phase 5 Milestone Verification

- [ ] **End-to-end test: complete MVP**
  - AC: Fresh install on clean Mac works
  - AC: Accessibility permission flow is smooth
  - AC: Lock toggle via Cmd+Shift+B is instant
  - AC: All input blocked except unlock hotkey
  - AC: Blue glow clearly visible
  - AC: Screen content (videos, etc.) fully visible
  - AC: Unlock is reliable (never stuck locked)
  - AC: Launch at Login works across restarts
  - AC: App uses minimal resources when idle
  - AC: App uses minimal resources when locked

---

## Final Verification

- [ ] **Real-world test: Baby watching screen**
  - AC: Play a video in fullscreen
  - AC: Activate lock with Cmd+Shift+B
  - AC: Video continues playing (visible through overlay)
  - AC: Blue glow indicates locked state
  - AC: Baby can mash keyboard with no effect
  - AC: Baby can touch trackpad with no effect
  - AC: Parent can unlock with Cmd+Shift+B
  - AC: All input immediately responsive after unlock

---

## Backlog (Post-MVP)

These items are deferred until after MVP is complete:

### UX Enhancements
- [ ] Preferences window for hotkey customization
- [ ] Sound effect on lock/unlock (optional)
- [ ] Custom glow color picker
- [ ] Glow pulse animation option
- [ ] Multiple lock modes (keyboard only, mouse only, full)

### Multi-Monitor Support
- [ ] Overlay on all connected monitors
- [ ] Per-monitor lock option
- [ ] Handle monitor hot-plug

### Advanced Features
- [ ] Touch Bar blocking (MacBooks with Touch Bar)
- [ ] Scheduled auto-lock timer
- [ ] Password/Touch ID to unlock
- [ ] Parental controls integration
- [ ] Screen time tracking while locked

### Distribution
- [ ] App icon design
- [ ] Welcome/onboarding window
- [ ] About window with version info
- [ ] Code signing with Developer ID
- [ ] Notarization for Gatekeeper
- [ ] DMG installer with drag-to-Applications
- [ ] Homebrew cask formula
- [ ] Auto-update mechanism

---

## Quick Reference: Key Components

```
BabyLockApp (Entry Point)
├── AppDelegate
│   ├── NSStatusItem (Menu Bar)
│   │   ├── Icon: lock.open / lock.fill
│   │   └── Menu: Toggle, Launch at Login, Quit
│   ├── LockManager
│   │   ├── isLocked: Bool
│   │   ├── toggle()
│   │   ├── engage() → show overlay, start interceptor
│   │   └── disengage() → stop interceptor, hide overlay
│   ├── InputInterceptor
│   │   ├── CGEventTap (session level)
│   │   ├── start() → enable tap
│   │   ├── stop() → disable tap
│   │   └── callback → block all except Cmd+Shift+B
│   └── OverlayWindow
│       ├── NSWindow (.screenSaver level)
│       ├── GlowBorderView (blue glow)
│       ├── show() → fade in
│       └── hide() → fade out
└── Permissions
    ├── Accessibility (required for CGEventTap)
    └── Launch at Login (SMAppService)
```

## Key Code Patterns

```swift
// Event tap callback signature
func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>?

// Check for unlock hotkey
if type == .keyDown {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    if keyCode == 11 && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        return Unmanaged.passUnretained(event)  // Allow through
    }
}
return nil  // Block everything else

// Window setup
window.level = .screenSaver
window.ignoresMouseEvents = true
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
```

## Notes

- Each checkbox represents a discrete, testable piece of work
- ACs should be verifiable by running the app or inspecting behavior
- Check off items as completed during implementation
- If an AC fails, fix before moving to next task
- Safety: Force Quit (Cmd+Option+Esc) should always work as escape hatch
- Safety: App termination always releases input (CGEventTap dies with process)
