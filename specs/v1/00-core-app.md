# 00: Core App

**Layer 0** - Foundation layer for app lifecycle, menu bar presence, and global hotkey registration.

## Overview

The core app layer manages:
- Menu bar app presence (no dock icon)
- Global hotkey registration (Cmd+Shift+B)
- Lock state management (on/off toggle)
- Coordination between input capture and visual overlay

## Dependencies

None - this is the foundation layer.

## App Architecture

```
+------------------------------------------------------------------+
|                         baby-lock process                          |
+------------------------------------------------------------------+
|                                                                    |
|   +----------------+      +-----------------+      +-----------+  |
|   | Menu Bar Item  |<---->|   Lock State    |<---->|  Overlay  |  |
|   | (NSStatusItem) |      |    Manager      |      |  Window   |  |
|   +----------------+      +-----------------+      +-----------+  |
|                                  ^                                 |
|                                  |                                 |
|                           +------+------+                          |
|                           |   Hotkey    |                          |
|                           |  Listener   |                          |
|                           +-------------+                          |
|                                                                    |
+------------------------------------------------------------------+
```

## Lock State Machine

```
            Cmd+Shift+B              Cmd+Shift+B
   +--------+  toggle   +---------+   toggle   +--------+
   |  IDLE  |---------->| LOCKED  |----------->|  IDLE  |
   +--------+           +---------+            +--------+
                             |
                             | (while locked)
                             v
                       +------------+
                       | Block ALL  |
                       |   Input    |
                       +------------+
```

## SwiftUI App Structure

### App Entry Point

```swift
@main
struct BabyLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { }  // Empty - menu bar only
    }
}
```

### AppDelegate

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var lockManager: LockManager?
    var hotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()
        lockManager = LockManager()
    }
}
```

## Menu Bar Implementation

### Status Item

```swift
func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
        button.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "Baby Lock")
    }

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Toggle Lock (Cmd+Shift+B)", action: #selector(toggleLock), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

    statusItem?.menu = menu
}
```

### Icon States

| State | Icon | Description |
|-------|------|-------------|
| Unlocked | `lock.open` | Normal state, input flows through |
| Locked | `lock.fill` | Baby mode active, all input blocked |

## Global Hotkey

### Registration with Carbon Events

```swift
import Carbon

func setupHotkey() {
    // Cmd+Shift+B
    let keyCode: UInt32 = 11  // 'B' key
    let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType("BABY".fourCharCode)
    hotKeyID.id = 1

    var eventType = EventTypeSpec()
    eventType.eventClass = OSType(kEventClassKeyboard)
    eventType.eventKind = OSType(kEventHotKeyPressed)

    InstallEventHandler(
        GetApplicationEventTarget(),
        hotkeyCallback,
        1,
        &eventType,
        nil,
        nil
    )

    RegisterEventHotKey(
        keyCode,
        modifiers,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
    )
}
```

### Alternative: NSEvent Global Monitor

```swift
func setupHotkey() {
    hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        // Cmd+Shift+B
        if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 11 {
            self.toggleLock()
        }
    }
}
```

## Lock Manager

```swift
class LockManager: ObservableObject {
    @Published var isLocked = false

    var inputInterceptor: InputInterceptor?
    var overlayWindow: OverlayWindow?

    func toggle() {
        isLocked.toggle()

        if isLocked {
            engage()
        } else {
            disengage()
        }
    }

    private func engage() {
        overlayWindow?.show()
        inputInterceptor?.start()
        updateMenuBarIcon(locked: true)
    }

    private func disengage() {
        inputInterceptor?.stop()
        overlayWindow?.hide()
        updateMenuBarIcon(locked: false)
    }
}
```

## LSUIElement (Hide Dock Icon)

In Info.plist:
```xml
<key>LSUIElement</key>
<true/>
```

This makes the app a menu bar-only application with no dock icon.

## Acceptance Criteria

### MVP Requirements

1. [ ] App launches as menu bar item (no dock icon)
2. [ ] Menu bar icon toggles between lock.open and lock.fill states
3. [ ] Cmd+Shift+B hotkey toggles lock on/off globally
4. [ ] Menu shows current state and toggle option
5. [ ] Clean quit via menu

### Post-MVP Requirements

1. [ ] Preferences window for hotkey customization
2. [ ] Sound effect on lock/unlock
3. [ ] Multiple lock modes (keyboard only, full, etc.)
