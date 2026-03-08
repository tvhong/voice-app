import Foundation

enum ModelConfig {
    static let selectedModelNameKey = "selectedWhisperKitModel"

    static let availableModelNames: [String] = [
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3"
    ]

    static var selectedModelName: String {
        get {
            let saved = UserDefaults.standard.string(forKey: selectedModelNameKey)
            return saved ?? "base"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedModelNameKey)
        }
    }
}
