import Foundation
import WhisperKit

enum WhisperKitModelStore {
    private static let requiredModelFiles = [
        "config.json",
        "generation_config.json",
        "AudioEncoder.mlmodelc/coremldata.bin",
        "MelSpectrogram.mlmodelc/coremldata.bin",
        "TextDecoder.mlmodelc/coremldata.bin"
    ]

    private static let requiredTokenizerFiles = ["tokenizer.json", "tokenizer_config.json"]

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

        guard let modelFolder = resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ) else { return false }

        return hasRequiredModelFiles(fileManager: fileManager, modelFolder: modelFolder)
            && hasRequiredTokenizerFiles(
                fileManager: fileManager,
                modelsRoot: modelsRoot,
                modelSuffix: modelSuffix
            )
    }

    static func estimatedDownloadSize(for model: String) -> String {
        estimatedDownloadSizes[model] ?? "Unknown"
    }

    static func deleteModel(_ model: String) throws {
        let fileManager = FileManager.default
        let modelSuffix = "whisper-\(model)"
        let modelsRoot = downloadBaseURL.appendingPathComponent("models", isDirectory: true)

        if let modelFolder = resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ), fileManager.fileExists(atPath: modelFolder.path) {
            try fileManager.removeItem(at: modelFolder)
        }

        let tokenizerFolder = modelsRoot
            .appendingPathComponent("openai", isDirectory: true)
            .appendingPathComponent(modelSuffix, isDirectory: true)

        if fileManager.fileExists(atPath: tokenizerFolder.path) {
            try fileManager.removeItem(at: tokenizerFolder)
        }
    }

    private static func resolveModelFolder(
        fileManager: FileManager,
        modelsRoot: URL,
        modelSuffix: String
    ) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: modelsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            guard isDirectory(url) else { continue }
            if url.lastPathComponent.hasSuffix(modelSuffix) {
                return url
            }
        }

        return nil
    }

    private static func hasRequiredModelFiles(fileManager: FileManager, modelFolder: URL) -> Bool {
        hasAllFiles(
            fileManager: fileManager,
            root: modelFolder,
            relativePaths: requiredModelFiles
        )
    }

    private static func hasRequiredTokenizerFiles(
        fileManager: FileManager,
        modelsRoot: URL,
        modelSuffix: String
    ) -> Bool {
        let tokenizerFolder = modelsRoot
            .appendingPathComponent("openai", isDirectory: true)
            .appendingPathComponent(modelSuffix, isDirectory: true)

        return hasAllFiles(
            fileManager: fileManager,
            root: tokenizerFolder,
            relativePaths: requiredTokenizerFiles
        )
    }

    private static func hasAllFiles(
        fileManager: FileManager,
        root: URL,
        relativePaths: [String]
    ) -> Bool {
        for relativePath in relativePaths {
            if !fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path) {
                return false
            }
        }
        return true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
