import SwiftUI

/// Setup guidance view shown on first launch to explain the app.
struct SetupGuidanceView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // App icon and title
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Welcome to Baby Lock")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top, 8)

            // What the app does
            VStack(alignment: .leading, spacing: 16) {
                SectionView(
                    icon: "hand.raised.fill",
                    title: "What it does",
                    description: "Baby Lock temporarily blocks all keyboard and mouse input, letting your baby safely watch the screen without accidentally pressing keys or clicking."
                )

                SectionView(
                    icon: "command",
                    title: "How to use",
                    description: "Press Cmd+Shift+B to lock/unlock. When locked, a blue glow border appears and all input is blocked except this unlock shortcut."
                )

                SectionView(
                    icon: "lock.shield.fill",
                    title: "Accessibility Permission",
                    description: "The app needs Accessibility permission to intercept keyboard and mouse input. macOS will prompt you to grant this in System Settings."
                )
            }
            .padding(.horizontal, 8)

            Spacer()

            // Get Started button
            Button(action: onDismiss) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 400, height: 420)
    }
}

/// A section with an icon, title, and description.
private struct SectionView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Window controller for the setup guidance window.
class SetupGuidanceWindowController {
    private var window: NSWindow?

    func showWindow(completion: @escaping () -> Void) {
        let contentView = SetupGuidanceView(onDismiss: { [weak self] in
            self?.closeWindow()
            completion()
        })

        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Baby Lock Setup"
        window?.contentView = hostingView
        window?.center()
        window?.isReleasedWhenClosed = false

        // Make the window key and bring to front
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
