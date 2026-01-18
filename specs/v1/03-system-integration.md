# 03: System Integration

**Layer 3** - macOS system integration: launch at login, permissions, and system dialog handling.

## Overview

The system integration layer handles:
- Launch at login (Login Items)
- Permission management (Accessibility)
- System dialog behavior during lock
- App sandbox considerations

## Dependencies

- **Layer 0**: Core App
- **Layer 1**: Input Interception (for accessibility permission)

## Launch at Login

### Using SMAppService (macOS 13+)

```swift
import ServiceManagement

class LaunchAtLoginManager {
    static func enable() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }

    static func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
```

### Legacy: Login Items (macOS 12 and earlier)

```swift
// Using LSSharedFileList (deprecated but works)
func addToLoginItems() {
    let bundleURL = Bundle.main.bundleURL as CFURL

    if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) {
        LSSharedFileListInsertItemURL(
            loginItems.takeRetainedValue(),
            kLSSharedFileListItemBeforeFirst.takeRetainedValue(),
            nil,
            nil,
            bundleURL,
            nil,
            nil
        )
    }
}
```

## Permission Management

### Accessibility Permission

Required for CGEventTap:

```swift
class PermissionManager {
    static func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

### Permission Check Flow

```
App Launch
    |
    v
Check Accessibility Permission
    |
    +---> Granted --> Ready to use
    |
    +---> Not Granted --> Show alert
                              |
                              v
                         User clicks "Grant"
                              |
                              v
                         Open System Preferences
                              |
                              v
                         User enables permission
                              |
                              v
                         App detects change --> Ready
```

### Monitoring Permission Changes

```swift
// Poll for permission changes (no notification API available)
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    if AXIsProcessTrusted() {
        // Permission granted, stop polling
        self.permissionGranted()
    }
}
```

## System Dialogs During Lock

System dialogs (low battery, notifications, etc.) will still appear. The overlay is transparent so they're visible, but the input interceptor blocks interaction.

### Notification Behavior

- Notifications appear normally (overlay is transparent)
- Clicking notifications is blocked (input interceptor)
- This is the desired behavior - user sees alerts but baby can't dismiss

### Critical System Dialogs

Some dialogs may bypass event taps:
- Force Quit (Cmd+Option+Esc) - WindowServer handles
- Emergency SOS
- Power button actions

This is intentional - maintains system safety.

## App Sandbox Considerations

### Entitlements Required

```xml
<!-- BabyLock.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- For launch at login -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

### Why No Sandbox

CGEventTap requires running outside the sandbox. The app will be:
- Distributed outside Mac App Store (direct download)
- Signed with Developer ID for Gatekeeper
- Notarized for macOS security

## Info.plist Configuration

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>

<key>NSHumanReadableCopyright</key>
<string>Copyright 2024</string>

<key>LSMinimumSystemVersion</key>
<string>12.0</string>
```

## First Launch Experience

```swift
func handleFirstLaunch() {
    let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

    if !hasLaunched {
        // Show welcome/setup
        showWelcomeWindow()

        // Request permissions
        PermissionManager.requestAccessibility()

        // Offer to enable launch at login
        promptLaunchAtLogin()

        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}
```

## Acceptance Criteria

### MVP Requirements

1. [ ] App can be set to launch at login
2. [ ] Accessibility permission requested on first launch
3. [ ] Clear guidance if permission not granted
4. [ ] Works correctly as non-sandboxed app
5. [ ] Proper Info.plist for menu bar app

### Post-MVP Requirements

1. [ ] Welcome/onboarding flow
2. [ ] Status indicator for permission state
3. [ ] Automatic permission re-check
4. [ ] Notarization for Gatekeeper

---

## Verification

To test the complete implementation:

1. Build and run the app
2. Grant Accessibility permission when prompted
3. Verify menu bar icon appears (lock.open)
4. Press Cmd+Shift+B - verify:
   - Icon changes to lock.fill
   - Blue glow border appears
   - All keyboard input blocked
   - All mouse/trackpad input blocked
5. Press Cmd+Shift+B again - verify:
   - Icon changes back to lock.open
   - Blue glow fades out
   - Input restored
6. Enable "Launch at Login" - restart Mac - verify app starts
