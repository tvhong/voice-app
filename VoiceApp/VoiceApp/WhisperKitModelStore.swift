import Foundation
import WhisperKit

enum WhisperKitModelStore {
    private static let requiredModelFiles = [
        "config.json",
        "generation_config.json",
        "AudioEncoder.mlmodelc/weights/weight.bin",
        "MelSpectrogram.mlmodelc/weights/weight.bin",
        "TextDecoder.mlmodelc/weights/weight.bin"
    ]

    private static let requiredTokenizerFiles = ["tokenizer.json", "tokenizer_config.json"]
    private static let manifestRevision = "1f92e0a7895c30ff3448ec31a65eb4acffcfd7de"
    private static var inMemoryVerificationCache: [String: Bool] = [:]

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

        guard let modelFolder = ModelFilesystem.resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ) else { return false }

        guard ModelFilesystem.hasRequiredModelFiles(
            fileManager: fileManager,
            modelFolder: modelFolder,
            requiredModelFiles: requiredModelFiles
        )
            && ModelFilesystem.hasValidTokenizerFilesIfPresent(
                fileManager: fileManager,
                modelsRoot: modelsRoot,
                modelSuffix: modelSuffix,
                requiredTokenizerFiles: requiredTokenizerFiles
            ) else {
            return false
        }

        if let cached = inMemoryVerificationCache[model] {
            return cached
        }

        let verified = ModelIntegrityVerifier.verifyIntegrityIfNeeded(
            model: model,
            modelFolder: modelFolder,
            manifestRevision: manifestRevision,
            downloadBaseURL: downloadBaseURL
        )
        inMemoryVerificationCache[model] = verified
        return verified
    }

    static func estimatedDownloadSize(for model: String) -> String {
        estimatedDownloadSizes[model] ?? "Unknown"
    }

    static func verifyAndMarkModel(_ model: String) -> Bool {
        let fileManager = FileManager.default
        let modelSuffix = "whisper-\(model)"
        let modelsRoot = downloadBaseURL.appendingPathComponent("models", isDirectory: true)

        guard let modelFolder = ModelFilesystem.resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ) else {
            inMemoryVerificationCache[model] = false
            return false
        }

        let isVerified = ModelIntegrityVerifier.verifyIntegrity(
            model: model,
            modelFolder: modelFolder,
            manifestRevision: manifestRevision,
            downloadBaseURL: downloadBaseURL
        )
        inMemoryVerificationCache[model] = isVerified
        return isVerified
    }

    static func deleteModel(_ model: String) throws {
        let fileManager = FileManager.default
        let modelSuffix = "whisper-\(model)"
        let modelsRoot = downloadBaseURL.appendingPathComponent("models", isDirectory: true)

        if let modelFolder = ModelFilesystem.resolveModelFolder(
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

        VerificationMarkerStore.removeMarker(for: model, downloadBaseURL: downloadBaseURL)
        inMemoryVerificationCache[model] = false
    }

}
