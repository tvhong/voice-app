import Foundation

enum ModelConfig {
    static let appSupportModelURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/ggml-base.en.bin")
    }()
}
