import SwiftUI
import AppKit

/// Settings view with shortcut configuration and launch at login toggle.
struct SettingsView: View {
    @State private var currentShortcut: KeyboardShortcut = ShortcutConfigurationManager.shared.currentShortcut
    @State private var launchAtLogin: Bool = LaunchAtLoginManager.isEnabled
    @State private var isRecording: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)

            // Shortcut section
            VStack(alignment: .leading, spacing: 12) {
                Text("Unlock Shortcut")
                    .font(.headline)

                HStack {
                    ShortcutRecorderButton(
                        shortcut: $currentShortcut,
                        isRecording: $isRecording,
                        onShortcutChanged: { newShortcut in
                            ShortcutConfigurationManager.shared.currentShortcut = newShortcut
                        }
                    )

                    Spacer()

                    Button("Reset to Default") {
                        ShortcutConfigurationManager.shared.resetToDefault()
                        currentShortcut = .defaultShortcut
                    }
                    .disabled(currentShortcut == .defaultShortcut)
                }

                Text("Press the shortcut to unlock when the screen is locked.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Launch at Login section
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.headline)
                        Text("Automatically start Baby Lock when you log in.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { newValue in
                    if newValue {
                        LaunchAtLoginManager.enable()
                    } else {
                        LaunchAtLoginManager.disable()
                    }
                }
                .disabled(!LaunchAtLoginManager.isAvailable)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 280)
        .onReceive(NotificationCenter.default.publisher(for: .shortcutDidChange)) { notification in
            if let shortcut = notification.object as? KeyboardShortcut {
                currentShortcut = shortcut
            }
        }
    }
}

/// A button that records keyboard shortcuts when clicked.
struct ShortcutRecorderButton: View {
    @Binding var shortcut: KeyboardShortcut
    @Binding var isRecording: Bool
    var onShortcutChanged: (KeyboardShortcut) -> Void

    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ShortcutRecorderRepresentable(
            shortcut: $shortcut,
            isRecording: $isRecording,
            onShortcutChanged: onShortcutChanged,
            showingError: $showingError,
            errorMessage: $errorMessage
        )
        .frame(width: 160, height: 28)
        .alert("Invalid Shortcut", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

/// NSViewRepresentable wrapper for keyboard event capture.
struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut
    @Binding var isRecording: Bool
    var onShortcutChanged: (KeyboardShortcut) -> Void
    @Binding var showingError: Bool
    @Binding var errorMessage: String

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRecording = isRecording
        nsView.updateDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: ShortcutRecorderDelegate {
        var parent: ShortcutRecorderRepresentable

        init(_ parent: ShortcutRecorderRepresentable) {
            self.parent = parent
        }

        func shortcutRecorder(_ recorder: ShortcutRecorderNSView, didRecordShortcut shortcut: KeyboardShortcut) {
            if shortcut.hasValidModifiers {
                parent.shortcut = shortcut
                parent.onShortcutChanged(shortcut)
                parent.isRecording = false
            } else {
                parent.errorMessage = "Please include at least Cmd, Ctrl, or Option modifier."
                parent.showingError = true
                parent.isRecording = false
            }
        }

        func shortcutRecorderDidStartRecording(_ recorder: ShortcutRecorderNSView) {
            parent.isRecording = true
        }

        func shortcutRecorderDidCancelRecording(_ recorder: ShortcutRecorderNSView) {
            parent.isRecording = false
        }
    }
}

/// Protocol for shortcut recorder delegate.
protocol ShortcutRecorderDelegate: AnyObject {
    func shortcutRecorder(_ recorder: ShortcutRecorderNSView, didRecordShortcut shortcut: KeyboardShortcut)
    func shortcutRecorderDidStartRecording(_ recorder: ShortcutRecorderNSView)
    func shortcutRecorderDidCancelRecording(_ recorder: ShortcutRecorderNSView)
}

/// NSView that captures keyboard events for shortcut recording.
class ShortcutRecorderNSView: NSView {
    weak var delegate: ShortcutRecorderDelegate?
    var shortcut: KeyboardShortcut = .defaultShortcut
    var isRecording: Bool = false {
        didSet { updateDisplay() }
    }

    private var button: NSButton!
    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        button = NSButton(frame: bounds)
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(buttonClicked)
        button.autoresizingMask = [.width, .height]
        addSubview(button)
        updateDisplay()
    }

    func updateDisplay() {
        if isRecording {
            button.title = "Press shortcut..."
            button.contentTintColor = .systemBlue
        } else {
            button.title = shortcut.displayString
            button.contentTintColor = nil
        }
    }

    @objc private func buttonClicked() {
        if isRecording {
            stopRecording(cancelled: true)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        delegate?.shortcutRecorderDidStartRecording(self)

        // Install local event monitor for key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            if event.type == .keyDown {
                // Escape cancels recording
                if event.keyCode == 53 {
                    self.stopRecording(cancelled: true)
                    return nil
                }

                let newShortcut = KeyboardShortcut(
                    keyCode: event.keyCode,
                    modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                )

                self.stopRecording(cancelled: false)
                self.delegate?.shortcutRecorder(self, didRecordShortcut: newShortcut)
                return nil
            }

            return event
        }

        // Make the button first responder
        window?.makeFirstResponder(self)
    }

    private func stopRecording(cancelled: Bool) {
        isRecording = false

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if cancelled {
            delegate?.shortcutRecorderDidCancelRecording(self)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording(cancelled: true)
        }
        return super.resignFirstResponder()
    }
}

/// Window controller for the settings window.
class SettingsWindowController {
    private var window: NSWindow?

    func showWindow() {
        // If window exists and is visible, just bring it to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Baby Lock Settings"
        window?.contentView = hostingView
        window?.center()
        window?.isReleasedWhenClosed = false

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
