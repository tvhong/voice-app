import AppKit

struct HotkeyShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt  // NSEvent.ModifierFlags.rawValue (device-independent only)
    let isFnOnly: Bool

    static let fn = HotkeyShortcut(keyCode: 0, modifiers: 0, isFnOnly: true)
    static let commandD = HotkeyShortcut(keyCode: 2, modifiers: NSEvent.ModifierFlags.command.rawValue, isFnOnly: false)
    static let optionZ = HotkeyShortcut(keyCode: 6, modifiers: NSEvent.ModifierFlags.option.rawValue, isFnOnly: false)

    /// Device-independent modifier flags for comparison.
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    /// Human-readable label like "⌘D" or "⌥Z".
    var label: String {
        if isFnOnly { return "Fn" }

        var parts: [String] = []
        let flags = modifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = Self.keyName(for: keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    private static func keyName(for keyCode: UInt16) -> String {
        // Map common key codes to readable names
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`",
            51: "Delete", 53: "Esc",
            36: "Return", 76: "Enter",
            115: "Home", 116: "PgUp", 117: "FwdDel", 119: "End", 121: "PgDn",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}

enum HotkeyMode: String, CaseIterable {
    case hold = "hold"
    case toggle = "toggle"

    var label: String {
        switch self {
        case .hold: "Hold to talk"
        case .toggle: "Press to toggle"
        }
    }
}

enum HotkeyConfig {
    static let modeKey = "hotkeyMode"
    static let shortcutKey = "hotkeyShortcut"

    // Legacy key for migration
    private static let legacyKeyKey = "hotkeyKey"

    static var mode: HotkeyMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey)
            return raw.flatMap(HotkeyMode.init(rawValue:)) ?? .toggle
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    static var shortcut: HotkeyShortcut {
        get {
            // Try new JSON format first
            if let data = UserDefaults.standard.data(forKey: shortcutKey),
               let s = try? JSONDecoder().decode(HotkeyShortcut.self, from: data) {
                return s
            }
            // Migrate from legacy enum
            if let legacy = UserDefaults.standard.string(forKey: legacyKeyKey) {
                switch legacy {
                case "fn": return .fn
                case "commandD": return .commandD
                default: break
                }
            }
            return .commandD
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: shortcutKey)
            }
            // Clean up legacy key
            UserDefaults.standard.removeObject(forKey: legacyKeyKey)
        }
    }
}
