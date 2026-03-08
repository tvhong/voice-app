import Foundation
import WhisperKit

enum ModelConfig {
    static let selectedModelNameKey = "selectedWhisperKitModel"
    static let preparedModelsKey = "preparedWhisperKitModels"

    static let availableModelNames: [String] = [
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3"
    ]

    private static let estimatedDownloadSizes: [String: String] = [
        "tiny": "~75 MB",
        "base": "~142 MB",
        "small": "~466 MB",
        "medium": "~1.5 GB",
        "large-v3": "~3.1 GB"
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

    static func markModelPrepared(_ model: String) {
        var models = Set(UserDefaults.standard.stringArray(forKey: preparedModelsKey) ?? [])
        models.insert(model)
        UserDefaults.standard.set(Array(models).sorted(), forKey: preparedModelsKey)
    }

    static func isModelPrepared(_ model: String) -> Bool {
        let models = Set(UserDefaults.standard.stringArray(forKey: preparedModelsKey) ?? [])
        return models.contains(model)
    }

    static func estimatedDownloadSize(for model: String) -> String {
        estimatedDownloadSizes[model] ?? "Unknown"
    }
}
