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

enum HotkeyConfig {
    static let modeKey = "hotkeyMode"

    static var mode: HotkeyMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey)
            return raw.flatMap(HotkeyMode.init(rawValue:)) ?? .hold
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }
}
