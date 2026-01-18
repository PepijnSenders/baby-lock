# 02: Visual Overlay

**Layer 2** - Transparent overlay window with soft blue glow border to indicate lock state.

## Overview

The visual overlay layer handles:
- Full-screen transparent window over all content
- Soft blue glow border around screen edges
- Click-through (events handled by input interceptor, not window)
- Smooth fade in/out animations

## Dependencies

- **Layer 0**: Core App (for lock state)
- **Layer 1**: Input Interception (overlay doesn't handle input)

## Overlay Architecture

```
+------------------------------------------------------------------+
|                        Display Stack                               |
+------------------------------------------------------------------+
|                                                                    |
|   +----------------------------------------------------------+    |
|   |              Overlay Window (topmost)                     |    |
|   |   +----------------------------------------------------+  |    |
|   |   |         Transparent Center                         |  |    |
|   |   |         (see-through to desktop)                   |  |    |
|   |   |                                                    |  |    |
|   |   |   +-----------------------------------------+      |  |    |
|   |   |   |  Blue glow border (inner shadow)       |      |  |    |
|   |   |   +-----------------------------------------+      |  |    |
|   |   +----------------------------------------------------+  |    |
|   +----------------------------------------------------------+    |
|                                                                    |
|   +----------------------------------------------------------+    |
|   |              Normal Desktop / Apps                        |    |
|   +----------------------------------------------------------+    |
|                                                                    |
+------------------------------------------------------------------+
```

## Window Configuration

### NSWindow Setup

```swift
class OverlayWindow: NSWindow {
    init() {
        let screenFrame = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Window configuration
        self.level = .screenSaver           // Above everything
        self.backgroundColor = .clear        // Transparent
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true       // Click-through
        self.collectionBehavior = [
            .canJoinAllSpaces,               // Show on all spaces
            .fullScreenAuxiliary,            // Show over fullscreen apps
            .stationary                      // Don't move with spaces
        ]
    }
}
```

### Window Level Hierarchy

| Level | Value | Use |
|-------|-------|-----|
| Normal | 0 | Regular windows |
| Floating | 3 | Always-on-top |
| Dock | 20 | Dock |
| Screen Saver | 1000 | Screen savers |
| **Overlay** | **1000** | Baby Lock uses this |

## Blue Glow Border

### SwiftUI Implementation

```swift
struct OverlayView: View {
    let glowColor = Color(red: 0.3, green: 0.6, blue: 1.0)  // Soft blue
    let glowWidth: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent center
                Color.clear

                // Border glow using inner shadow effect
                RoundedRectangle(cornerRadius: 0)
                    .stroke(glowColor, lineWidth: glowWidth)
                    .blur(radius: 20)
                    .opacity(0.6)

                // Sharper inner edge
                RoundedRectangle(cornerRadius: 0)
                    .stroke(glowColor, lineWidth: 4)
                    .blur(radius: 4)
                    .opacity(0.8)
            }
        }
        .ignoresSafeArea()
    }
}
```

### AppKit/Core Animation Implementation

```swift
class GlowBorderView: NSView {
    private let glowColor = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear background
        context.clear(bounds)

        // Draw glow border
        let borderWidth: CGFloat = 40
        let blurRadius: CGFloat = 20

        context.setShadow(offset: .zero, blur: blurRadius, color: glowColor.cgColor)
        context.setStrokeColor(glowColor.cgColor)
        context.setLineWidth(borderWidth)

        let insetRect = bounds.insetBy(dx: borderWidth/2, dy: borderWidth/2)
        context.stroke(insetRect)
    }
}
```

## Animation

### Fade In/Out

```swift
extension OverlayWindow {
    func show() {
        self.alphaValue = 0
        self.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
```

### Optional: Pulsing Glow

```swift
// Subtle pulse animation to indicate active lock
func startPulse() {
    let animation = CABasicAnimation(keyPath: "opacity")
    animation.fromValue = 0.6
    animation.toValue = 0.8
    animation.duration = 2.0
    animation.autoreverses = true
    animation.repeatCount = .infinity
    glowLayer.add(animation, forKey: "pulse")
}
```

## Handling Multiple Monitors

For MVP: main display only.

```swift
func setupForMainDisplay() {
    guard let mainScreen = NSScreen.main else { return }
    self.setFrame(mainScreen.frame, display: true)
}
```

## Click-Through Behavior

The window must not intercept any clicks - the Input Interceptor handles that.

```swift
// In window init
self.ignoresMouseEvents = true

// Alternative: override hit test
override func hitTest(_ point: NSPoint) -> NSView? {
    return nil  // Never accept clicks
}
```

## Acceptance Criteria

### MVP Requirements

1. [ ] Overlay window covers entire main screen
2. [ ] Window is transparent in center (desktop visible)
3. [ ] Soft blue glow visible around screen edges
4. [ ] Window appears above all other windows including fullscreen apps
5. [ ] Smooth fade in/out animation
6. [ ] Window doesn't intercept any mouse events

### Post-MVP Requirements

1. [ ] Support multiple monitors
2. [ ] Customizable glow color
3. [ ] Optional pulse animation
4. [ ] Match glow to system accent color
