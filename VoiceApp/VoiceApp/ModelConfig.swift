import Foundation

enum ModelConfig {
    static let appSupportModelURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/ggml-base.en.bin")
    }()

    static let customModelPathKey = "customModelPath"

    static var customModelURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: customModelPathKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: customModelPathKey)
        }
    }

    static func resolveModelURL() throws -> URL {
        if let custom = customModelURL {
            guard FileManager.default.fileExists(atPath: custom.path) else {
                throw ModelError.modelNotFound(expectedPath: custom.path)
            }
            return custom
        }

        if FileManager.default.fileExists(atPath: appSupportModelURL.path) {
            return appSupportModelURL
        }

        if let bundleURL = Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") {
            return bundleURL
        }

        throw ModelError.modelNotFound(expectedPath: appSupportModelURL.path)
    }
}

enum ModelError: LocalizedError {
    case modelNotFound(expectedPath: String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Whisper model not found. Expected at:\n\(path)"
        }
    }
}
