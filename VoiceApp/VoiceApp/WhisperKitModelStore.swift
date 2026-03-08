import Foundation
import CryptoKit
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

        guard let modelFolder = resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ) else { return false }

        guard hasRequiredModelFiles(fileManager: fileManager, modelFolder: modelFolder)
            && hasValidTokenizerFilesIfPresent(
                fileManager: fileManager,
                modelsRoot: modelsRoot,
                modelSuffix: modelSuffix
            ) else {
            return false
        }

        if let cached = inMemoryVerificationCache[model] {
            return cached
        }

        let verified = verifyIntegrityIfNeeded(model: model, modelFolder: modelFolder)
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

        guard let modelFolder = resolveModelFolder(
            fileManager: fileManager,
            modelsRoot: modelsRoot,
            modelSuffix: modelSuffix
        ) else {
            inMemoryVerificationCache[model] = false
            return false
        }

        let isVerified = verifyIntegrity(model: model, modelFolder: modelFolder)
        inMemoryVerificationCache[model] = isVerified
        return isVerified
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

        try? fileManager.removeItem(at: verificationMarkerURL(for: model))
        inMemoryVerificationCache[model] = false
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

    private static func hasValidTokenizerFilesIfPresent(
        fileManager: FileManager,
        modelsRoot: URL,
        modelSuffix: String
    ) -> Bool {
        let tokenizerFolder = modelsRoot
            .appendingPathComponent("openai", isDirectory: true)
            .appendingPathComponent(modelSuffix, isDirectory: true)

        // Newer WhisperKit layouts may not place tokenizer files in this cache path.
        // If the tokenizer folder is absent, treat the model as prepared.
        guard fileManager.fileExists(atPath: tokenizerFolder.path) else {
            return true
        }

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

    private static func verifyIntegrityIfNeeded(model: String, modelFolder: URL) -> Bool {
        guard let manifest = expectedHashesByModel[model] else {
            return true
        }

        if hasValidMarker(for: model, modelFolder: modelFolder, manifest: manifest) {
            return true
        }

        return verifyIntegrity(model: model, modelFolder: modelFolder)
    }

    private static func verifyIntegrity(model: String, modelFolder: URL) -> Bool {
        guard let manifest = expectedHashesByModel[model] else {
            return true
        }

        var fingerprints: [String: FileFingerprint] = [:]
        for (relativePath, expectedHash) in manifest {
            let fileURL = modelFolder.appendingPathComponent(relativePath)
            guard let fingerprint = currentFingerprint(for: fileURL),
                  let actualHash = sha256(for: fileURL),
                  actualHash == expectedHash else {
                return false
            }
            fingerprints[relativePath] = fingerprint
        }

        writeMarker(
            VerificationMarker(
                manifestRevision: manifestRevision,
                fingerprints: fingerprints
            ),
            for: model
        )
        return true
    }

    private static func sha256(for fileURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let data = try? handle.read(upToCount: 1_048_576) else { return nil }
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func hasValidMarker(
        for model: String,
        modelFolder: URL,
        manifest: [String: String]
    ) -> Bool {
        let markerURL = verificationMarkerURL(for: model)
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(VerificationMarker.self, from: data),
              marker.manifestRevision == manifestRevision else {
            return false
        }

        for relativePath in manifest.keys {
            guard let expected = marker.fingerprints[relativePath],
                  let current = currentFingerprint(for: modelFolder.appendingPathComponent(relativePath)),
                  current == expected else {
                return false
            }
        }

        return true
    }

    private static func writeMarker(_ marker: VerificationMarker, for model: String) {
        let markerURL = verificationMarkerURL(for: model)
        let markerDir = markerURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: markerDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(marker)
            try data.write(to: markerURL, options: .atomic)
        } catch {
            // Marker write failures should not block model usage.
        }
    }

    private static func verificationMarkerURL(for model: String) -> URL {
        downloadBaseURL
            .appendingPathComponent("verification", isDirectory: true)
            .appendingPathComponent("\(model).json")
    }

    private static func currentFingerprint(for fileURL: URL) -> FileFingerprint? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? NSNumber,
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }

        return FileFingerprint(
            size: size.int64Value,
            modifiedAt: modified.timeIntervalSince1970
        )
    }

    private struct VerificationMarker: Codable {
        let manifestRevision: String
        let fingerprints: [String: FileFingerprint]
    }

    private struct FileFingerprint: Codable, Equatable {
        let size: Int64
        let modifiedAt: TimeInterval
    }

    private static let expectedHashesByModel: [String: [String: String]] = [
        "tiny": [
            "config.json": "9b59f5e09030bd142035cb2e1456c9edfaf6de11194b79d9d05f27a86571a74c",
            "generation_config.json": "45738853cc16804f73edfa036a56409cc7403ab99424876fc1abe0a9ccf5c6f2",
            "AudioEncoder.mlmodelc/model.mlmodel": "030d64a3ddd296d6f709691a66a870aab7ee9f19e5fe07e8086245fb85302802",
            "AudioEncoder.mlmodelc/weights/weight.bin": "bcd0879f6d1c61832765c7ec05d883d0dcbf1504057b13095fd315484196fc5e",
            "MelSpectrogram.mlmodelc/weights/weight.bin": "5b65b76f4e1dab57239e3946f6ab1314a7d1fdfa114485683dd04476ca62adb6",
            "TextDecoder.mlmodelc/model.mlmodel": "1afdfc3a8f3e8d6afc46e1ecc5fb216eadccbf82d9c568e7dbd3955143a1cd0e",
            "TextDecoder.mlmodelc/weights/weight.bin": "d0313e1a4ffa88538c141cc3c73e6eb0e3dc54db9d574b21c7c034de688e4951"
        ],
        "base": [
            "config.json": "67e25477d03bf3a1c34bfd137724beed94b5218d0457e8c1d25f70379a61d9d5",
            "generation_config.json": "662a99e3db3067708549d04d5f141910eb455f0935aed0c9b06d707f44bfbcaf",
            "AudioEncoder.mlmodelc/model.mlmodel": "1d42038f84b508da5ce9b953302387ffedc097c346d36a56b765109002b6080e",
            "AudioEncoder.mlmodelc/weights/weight.bin": "061ff4d74e5de3937b31288465d6c6f2697f92d121c80b23f51dd26bbdfe642b",
            "MelSpectrogram.mlmodelc/weights/weight.bin": "35d74417ef9c765e70f4ef85fe7405015a7086e9af05e3b63a5c2c7c748b2efc",
            "TextDecoder.mlmodelc/model.mlmodel": "ae260ff7b95d0c957c3c1f4df4dbeaa0ae6c76bacc55eb86caca8f6820d346f0",
            "TextDecoder.mlmodelc/weights/weight.bin": "72325d42a4a4ccc8a6fa974ede6cdf2e0770685a5c4f9da94f41495b94d8d174"
        ],
        "small": [
            "config.json": "12f8d45c3e5da28148d88d257684e77296e4d922009e1bc5289b05b756859422",
            "generation_config.json": "169e76633bb28ac383cdfaad2527e662d0d532a15f8437ce94c02c10bc713b71",
            "AudioEncoder.mlmodelc/model.mlmodel": "68ca04660b8b050c68ca54c27d97c47e4133bc591422cb7009de8922d56fb8c9",
            "AudioEncoder.mlmodelc/weights/weight.bin": "fe35cef2c9406993a635639b16f373f6debb0215ac115b7bf93fa03c8e10310b",
            "MelSpectrogram.mlmodelc/weights/weight.bin": "267017e533b5f542d195fd9a775f2ba649075128283ce8e86c63a2ec20de5b07",
            "TextDecoder.mlmodelc/model.mlmodel": "7ea861c6dfdd866ed0f2e7fe0c3df7459daa44481cb25236e03698dd6d259391",
            "TextDecoder.mlmodelc/weights/weight.bin": "bfea8044a8f38e8d33f56585b1e75ce023d3845e2a945e20480bd7e16558016e"
        ],
        "medium": [
            "config.json": "25857725440d110777730fc27762b9c2415f068282dcc9535cf9d929740f9894",
            "generation_config.json": "9e805015e900f8c96138cc3db93843bccc1912fa17a188abbdefcfbe1bf25734",
            "AudioEncoder.mlmodelc/weights/weight.bin": "577c78ed7e0ae71f9ed6fdb063dc74a0f4c0c44d04118111650458973f7ddae6",
            "MelSpectrogram.mlmodelc/weights/weight.bin": "801024dbc7a89c677be1f8b285de3409e35f7d1786c9c8d9d0d6842ac57a1c83",
            "TextDecoder.mlmodelc/weights/weight.bin": "283878d285cb0e557eeb1c6a1524eb5fd33cae2c289a114bc9e72ca76c0bfc75"
        ],
        "large-v3": [
            "config.json": "798b69c08cf93b2b03d94bea6eb3eb25fd4712259712d8a62ed2483fdf818a9e",
            "generation_config.json": "d24f9cca0f448609a71ae044b736023706382f45e9700e0dffb2559d10cf1fea",
            "AudioEncoder.mlmodelc/model.mlmodel": "bf0987c0d8c3fe180877b12ba5b4ac1d890e011f2103926e53186089feced575",
            "AudioEncoder.mlmodelc/weights/weight.bin": "eb07bab32dcd62ce653b5b288bd6c27bdc5a538be309f242e33ed05e1cb53457",
            "MelSpectrogram.mlmodelc/weights/weight.bin": "97a66b915cd3fc97dcba6806d92381e1a56024b8f68c1a1cd370d4c92505fe87",
            "TextDecoder.mlmodelc/model.mlmodel": "680d8dfb7c7d8f1f852071ac7bdc96e55c696d0b822e70861045efb426b0a27b",
            "TextDecoder.mlmodelc/weights/weight.bin": "680f398925225a313c62da0221aa0a58c9f1bffac5c36f20c449a70a7c9b1e55"
        ]
    ]
}
