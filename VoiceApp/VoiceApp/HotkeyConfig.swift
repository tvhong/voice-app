import Foundation

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

enum HotkeyKey: String, CaseIterable {
    case fn = "fn"
    case commandD = "commandD"

    var label: String {
        switch self {
        case .fn: "Fn"
        case .commandD: "⌘D"
        }
    }
}

enum HotkeyConfig {
    static let modeKey = "hotkeyMode"
    static let keyKey = "hotkeyKey"

    static var mode: HotkeyMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey)
            return raw.flatMap(HotkeyMode.init(rawValue:)) ?? .hold
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    static var key: HotkeyKey {
        get {
            let raw = UserDefaults.standard.string(forKey: keyKey)
            return raw.flatMap(HotkeyKey.init(rawValue:)) ?? .fn
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: keyKey)
        }
    }
}
