import Foundation
import WhisperKit

enum WhisperKitModelStore {
    private static let estimatedDownloadSizes: [String: String] = [
        "tiny": "~75 MB",
        "base": "~142 MB",
        "small": "~466 MB",
        "medium": "~1.5 GB",
        "large-v3": "~3.1 GB"
    ]

    static var downloadBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/WhisperKitModels", isDirectory: true)
    }

    static func makeConfig(model: String) -> WhisperKitConfig {
        WhisperKitConfig(
            model: model,
            downloadBase: downloadBaseURL,
            verbose: false
        )
    }

    static func isModelPrepared(_ model: String) -> Bool {
        let fileManager = FileManager.default
        let modelSuffix = "whisper-\(model)"
        let modelsRoot = downloadBaseURL.appendingPathComponent("models", isDirectory: true)

        guard let enumerator = fileManager.enumerator(
            at: modelsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var resolvedModelFolder: URL?
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if url.lastPathComponent.hasSuffix(modelSuffix) {
                resolvedModelFolder = url
                break
            }
        }

        guard let modelFolder = resolvedModelFolder else { return false }

        let requiredModelFiles = [
            "config.json",
            "generation_config.json",
            "AudioEncoder.mlmodelc/coremldata.bin",
            "MelSpectrogram.mlmodelc/coremldata.bin",
            "TextDecoder.mlmodelc/coremldata.bin"
        ]

        for relativePath in requiredModelFiles {
            let absolutePath = modelFolder.appendingPathComponent(relativePath).path
            if !fileManager.fileExists(atPath: absolutePath) {
                return false
            }
        }

        let tokenizerFolder = modelsRoot
            .appendingPathComponent("openai", isDirectory: true)
            .appendingPathComponent(modelSuffix, isDirectory: true)
        let requiredTokenizerFiles = ["tokenizer.json", "tokenizer_config.json"]
        for fileName in requiredTokenizerFiles {
            if !fileManager.fileExists(atPath: tokenizerFolder.appendingPathComponent(fileName).path) {
                return false
            }
        }

        return true
    }

    static func estimatedDownloadSize(for model: String) -> String {
        estimatedDownloadSizes[model] ?? "Unknown"
    }
}
