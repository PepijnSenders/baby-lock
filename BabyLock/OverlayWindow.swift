import AppKit
import SwiftUI

/// Full-screen transparent overlay window with soft blue glow border.
/// Indicates lock state is active while allowing screen content to remain visible.
class OverlayWindow: NSWindow {

    /// Tracks current animation to allow cancellation
    private var currentAnimationContext: NSAnimationContext?

    /// Completion handler for current animation
    private var currentCompletion: (() -> Void)?

    /// Model for keystroke overlay animations
    let keystrokeModel = KeystrokeOverlayModel()

    init() {
        let screenFrame = NSScreen.main?.frame ?? .zero

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Window configuration per spec 02-visual-overlay.md
        self.level = .screenSaver           // Above everything (level 1000)
        self.backgroundColor = .clear        // Transparent
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true       // Click-through - input handled by InputInterceptor
        self.collectionBehavior = [
            .canJoinAllSpaces,               // Show on all spaces/desktops
            .fullScreenAuxiliary,            // Show over fullscreen apps
            .stationary                      // Don't move with space switches
        ]

        // Set up the glow border view
        setupGlowBorderView()

        // Observe screen parameter changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Sets up the SwiftUI glow border view as window content
    private func setupGlowBorderView() {
        let combinedView = CombinedOverlayView(keystrokeModel: keystrokeModel)
        let hostingView = NSHostingView(rootView: combinedView)
        hostingView.frame = self.frame
        self.contentView = hostingView
    }

    /// Shows a floating letter at a random position on screen
    func showLetter(_ character: String) {
        guard let screen = NSScreen.main else { return }
        keystrokeModel.addLetter(character, screenSize: screen.frame.size)
    }

    /// Handles screen resolution/configuration changes
    @objc private func screenParametersChanged(_ notification: Notification) {
        guard let mainScreen = NSScreen.main else { return }
        self.setFrame(mainScreen.frame, display: true)
        print("[OverlayWindow] Screen parameters changed - updated frame to \(mainScreen.frame)")
    }

    /// Cancels any in-progress animation and resets to immediate state
    private func cancelPendingAnimation() {
        // Immediately finish any pending animation by setting alpha directly
        self.animator().alphaValue = self.alphaValue
        currentCompletion = nil
    }

    /// Shows the overlay with fade-in animation
    /// - Parameter completion: Optional callback when animation completes
    func show(completion: (() -> Void)? = nil) {
        guard let mainScreen = NSScreen.main else {
            print("[OverlayWindow] Cannot show - no main screen available")
            completion?()
            return
        }

        // Cancel any pending animation
        cancelPendingAnimation()

        // Ensure frame matches current screen
        self.setFrame(mainScreen.frame, display: false)

        // Start transparent
        self.alphaValue = 0
        self.orderFrontRegardless()

        currentCompletion = completion

        // Animate fade in (0.3 seconds per spec)
        // Use allowsImplicitAnimation for smoother 60fps animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.currentCompletion?()
            self?.currentCompletion = nil
            print("[OverlayWindow] Overlay shown with fade-in animation")
        })
    }

    /// Hides the overlay with fade-out animation
    /// - Parameter completion: Optional callback when animation completes
    func hide(completion: (() -> Void)? = nil) {
        // Cancel any pending animation
        cancelPendingAnimation()

        currentCompletion = completion

        // Animate fade out (0.2 seconds per spec)
        // Use allowsImplicitAnimation for smoother 60fps animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.currentCompletion?()
            self?.currentCompletion = nil
            print("[OverlayWindow] Overlay hidden with fade-out animation")
        })
    }
}

/// Combined view with glow border and keystroke overlay
struct CombinedOverlayView: View {
    @ObservedObject var keystrokeModel: KeystrokeOverlayModel

    var body: some View {
        ZStack {
            GlowBorderView()
            KeystrokeOverlayView(model: keystrokeModel)
        }
    }
}

/// SwiftUI view for the soft blue glow border effect
/// Optimized for minimal CPU usage when displayed as a static overlay
struct GlowBorderView: View {
    // Soft blue glow color: RGB(0.3, 0.6, 1.0) per spec
    let glowColor = Color(red: 0.3, green: 0.6, blue: 1.0)
    let glowWidth: CGFloat = 40
    let blurRadius: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent center - allows desktop to show through
                Color.clear

                // Outer glow with blur for soft effect
                Rectangle()
                    .stroke(glowColor, lineWidth: glowWidth)
                    .blur(radius: blurRadius)
                    .opacity(0.6)

                // Sharper inner edge for definition
                Rectangle()
                    .stroke(glowColor, lineWidth: 4)
                    .blur(radius: 4)
                    .opacity(0.8)
            }
            // Rasterize the glow effect to a bitmap for GPU efficiency
            // This prevents continuous re-rendering of blur effects
            .drawingGroup()
        }
        .ignoresSafeArea()
        // Disable hit testing since window already ignores mouse events
        .allowsHitTesting(false)
    }
}
