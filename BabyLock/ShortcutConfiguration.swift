import AppKit
import CoreGraphics

/// Represents a keyboard shortcut with a key code and modifier flags.
struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt

    /// Default shortcut: Cmd+Shift+B
    static let defaultShortcut = KeyboardShortcut(keyCode: 11, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)

    /// Checks if the given NSEvent matches this shortcut.
    func matches(event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else { return false }

        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcutModifiers = NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)

        return eventModifiers == shortcutModifiers
    }

    /// Checks if the given CGEvent matches this shortcut.
    func matches(cgEvent: CGEvent) -> Bool {
        let eventKeyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)
        guard eventKeyCode == Int64(keyCode) else { return false }

        let flags = cgEvent.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasOption = flags.contains(.maskAlternate)
        let hasControl = flags.contains(.maskControl)

        let shortcutModifiers = NSEvent.ModifierFlags(rawValue: modifiers)
        let expectCommand = shortcutModifiers.contains(.command)
        let expectShift = shortcutModifiers.contains(.shift)
        let expectOption = shortcutModifiers.contains(.option)
        let expectControl = shortcutModifiers.contains(.control)

        return hasCommand == expectCommand &&
               hasShift == expectShift &&
               hasOption == expectOption &&
               hasControl == expectControl
    }

    /// Human-readable display string for this shortcut.
    var displayString: String {
        var parts: [String] = []

        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifiers)
        if modifierFlags.contains(.control) { parts.append("Ctrl") }
        if modifierFlags.contains(.option) { parts.append("Option") }
        if modifierFlags.contains(.shift) { parts.append("Shift") }
        if modifierFlags.contains(.command) { parts.append("Cmd") }

        if let keyName = KeyboardShortcut.keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.joined(separator: "+")
    }

    /// Converts a key code to its string representation.
    private static func keyCodeToString(_ keyCode: UInt16) -> String? {
        // Common key mappings
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "Left", 124: "Right", 125: "Down", 126: "Up"
        ]
        return keyMap[keyCode]
    }

    /// Checks if the shortcut has valid modifiers (at least Cmd, Ctrl, or Option).
    var hasValidModifiers: Bool {
        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifiers)
        return modifierFlags.contains(.command) ||
               modifierFlags.contains(.control) ||
               modifierFlags.contains(.option)
    }
}

/// Notification posted when the shortcut configuration changes.
extension Notification.Name {
    static let shortcutDidChange = Notification.Name("shortcutDidChange")
}

/// Manages persistence and access to the keyboard shortcut configuration.
final class ShortcutConfigurationManager {
    static let shared = ShortcutConfigurationManager()

    private let userDefaultsKey = "keyboardShortcut"

    private init() {}

    /// The currently configured shortcut.
    var currentShortcut: KeyboardShortcut {
        get {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) else {
                return .defaultShortcut
            }
            return shortcut
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
                NotificationCenter.default.post(name: .shortcutDidChange, object: newValue)
                print("[ShortcutConfigurationManager] Shortcut updated to: \(newValue.displayString)")
            }
        }
    }

    /// Resets the shortcut to the default (Cmd+Shift+B).
    func resetToDefault() {
        currentShortcut = .defaultShortcut
    }
}
