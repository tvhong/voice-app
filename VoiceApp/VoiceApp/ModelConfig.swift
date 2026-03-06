import Foundation

enum ModelConfig {
    static let appSupportModelURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/ggml-base.en.bin")
    }()

    private static let customModelPathKey = "customModelPath"

    static var customModelURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: customModelPathKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: customModelPathKey)
        }
    }

    static var effectiveModelURL: URL {
        customModelURL ?? appSupportModelURL
    }
}
