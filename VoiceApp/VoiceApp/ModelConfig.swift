import Foundation
import WhisperKit

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

    static var whisperKitDownloadBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/WhisperKitModels", isDirectory: true)
    }

    static func makeWhisperKitConfig() -> WhisperKitConfig {
        WhisperKitConfig(
            model: selectedModelName,
            downloadBase: whisperKitDownloadBaseURL,
            verbose: false
        )
    }
}
