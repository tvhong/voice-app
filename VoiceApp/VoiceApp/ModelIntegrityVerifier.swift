import CryptoKit
import Foundation

enum ModelIntegrityVerifier {
    static func verifyIntegrityIfNeeded(
        model: String,
        modelFolder: URL,
        manifestRevision: String,
        downloadBaseURL: URL
    ) -> Bool {
        guard let manifest = expectedHashesByModel[model] else {
            print("[Verify] No manifest for model '\(model)' — skipping verification")
            return true
        }

        if VerificationMarkerStore.hasValidMarker(
            for: model,
            modelFolder: modelFolder,
            manifest: manifest,
            manifestRevision: manifestRevision,
            downloadBaseURL: downloadBaseURL
        ) {
            print("[Verify] Valid cached marker found for '\(model)' — skipping full hash check")
            return true
        }

        print("[Verify] No valid marker for '\(model)' — running full integrity check")
        return verifyIntegrity(
            model: model,
            modelFolder: modelFolder,
            manifestRevision: manifestRevision,
            downloadBaseURL: downloadBaseURL
        )
    }

    static func verifyIntegrity(
        model: String,
        modelFolder: URL,
        manifestRevision: String,
        downloadBaseURL: URL
    ) -> Bool {
        guard let manifest = expectedHashesByModel[model] else {
            return true
        }

        var fingerprints: [String: VerificationMarkerStore.FileFingerprint] = [:]
        for (relativePath, expectedHash) in manifest {
            let fileURL = modelFolder.appendingPathComponent(relativePath)
            print("[Verify] Checking '\(relativePath)'")

            guard let fingerprint = VerificationMarkerStore.currentFingerprint(for: fileURL) else {
                print(
                    "[Verify] FAIL: could not read file attributes for '\(relativePath)' at \(fileURL.path)"
                )
                return false
            }

            guard let actualHash = sha256(for: fileURL) else {
                print("[Verify] FAIL: could not compute SHA-256 for '\(relativePath)'")
                return false
            }

            guard actualHash == expectedHash else {
                print("[Verify] FAIL: hash mismatch for '\(relativePath)'")
                print("[Verify]   expected: \(expectedHash)")
                print("[Verify]   actual:   \(actualHash)")
                return false
            }

            print("[Verify] OK: '\(relativePath)'")
            fingerprints[relativePath] = fingerprint
        }

        VerificationMarkerStore.writeMarker(
            for: model,
            manifestRevision: manifestRevision,
            fingerprints: fingerprints,
            downloadBaseURL: downloadBaseURL
        )
        return true
    }

    private static func sha256(for fileURL: URL) -> String? {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            print("[Verify] SHA-256 open failed for '\(fileURL.lastPathComponent)': \(error)")
            print("[Verify]   full path: \(fileURL.path)")
            print("[Verify]   file exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                print("[Verify]   file type: \(attrs[.type] ?? "unknown")")
            }
            return nil
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let data = try? handle.read(upToCount: 1_048_576) else { return nil }
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static let expectedHashesByModel: [String: [String: String]] = [
        "tiny": [
            "config.json": "9b59f5e09030bd142035cb2e1456c9edfaf6de11194b79d9d05f27a86571a74c",
            "generation_config.json":
                "45738853cc16804f73edfa036a56409cc7403ab99424876fc1abe0a9ccf5c6f2",
            "AudioEncoder.mlmodelc/model.mlmodel":
                "030d64a3ddd296d6f709691a66a870aab7ee9f19e5fe07e8086245fb85302802",
            "AudioEncoder.mlmodelc/weights/weight.bin":
                "bcd0879f6d1c61832765c7ec05d883d0dcbf1504057b13095fd315484196fc5e",
            "MelSpectrogram.mlmodelc/weights/weight.bin":
                "5b65b76f4e1dab57239e3946f6ab1314a7d1fdfa114485683dd04476ca62adb6",
            "TextDecoder.mlmodelc/model.mlmodel":
                "1afdfc3a8f3e8d6afc46e1ecc5fb216eadccbf82d9c568e7dbd3955143a1cd0e",
            "TextDecoder.mlmodelc/weights/weight.bin":
                "d0313e1a4ffa88538c141cc3c73e6eb0e3dc54db9d574b21c7c034de688e4951",
        ],
        "base": [
            "config.json": "67e25477d03bf3a1c34bfd137724beed94b5218d0457e8c1d25f70379a61d9d5",
            "generation_config.json":
                "662a99e3db3067708549d04d5f141910eb455f0935aed0c9b06d707f44bfbcaf",
            "AudioEncoder.mlmodelc/model.mlmodel":
                "1d42038f84b508da5ce9b953302387ffedc097c346d36a56b765109002b6080e",
            "AudioEncoder.mlmodelc/weights/weight.bin":
                "061ff4d74e5de3937b31288465d6c6f2697f92d121c80b23f51dd26bbdfe642b",
            "MelSpectrogram.mlmodelc/weights/weight.bin":
                "35d74417ef9c765e70f4ef85fe7405015a7086e9af05e3b63a5c2c7c748b2efc",
            "TextDecoder.mlmodelc/model.mlmodel":
                "ae260ff7b95d0c957c3c1f4df4dbeaa0ae6c76bacc55eb86caca8f6820d346f0",
            "TextDecoder.mlmodelc/weights/weight.bin":
                "72325d42a4a4ccc8a6fa974ede6cdf2e0770685a5c4f9da94f41495b94d8d174",
        ],
        "small": [
            "config.json": "12f8d45c3e5da28148d88d257684e77296e4d922009e1bc5289b05b756859422",
            "generation_config.json":
                "169e76633bb28ac383cdfaad2527e662d0d532a15f8437ce94c02c10bc713b71",
            "AudioEncoder.mlmodelc/model.mlmodel":
                "68ca04660b8b050c68ca54c27d97c47e4133bc591422cb7009de8922d56fb8c9",
            "AudioEncoder.mlmodelc/weights/weight.bin":
                "fe35cef2c9406993a635639b16f373f6debb0215ac115b7bf93fa03c8e10310b",
            "MelSpectrogram.mlmodelc/weights/weight.bin":
                "267017e533b5f542d195fd9a775f2ba649075128283ce8e86c63a2ec20de5b07",
            "TextDecoder.mlmodelc/model.mlmodel":
                "7ea861c6dfdd866ed0f2e7fe0c3df7459daa44481cb25236e03698dd6d259391",
            "TextDecoder.mlmodelc/weights/weight.bin":
                "bfea8044a8f38e8d33f56585b1e75ce023d3845e2a945e20480bd7e16558016e",
        ],
        "medium": [
            "config.json": "25857725440d110777730fc27762b9c2415f068282dcc9535cf9d929740f9894",
            "generation_config.json":
                "9e805015e900f8c96138cc3db93843bccc1912fa17a188abbdefcfbe1bf25734",
            "AudioEncoder.mlmodelc/weights/weight.bin":
                "577c78ed7e0ae71f9ed6fdb063dc74a0f4c0c44d04118111650458973f7ddae6",
            "MelSpectrogram.mlmodelc/weights/weight.bin":
                "801024dbc7a89c677be1f8b285de3409e35f7d1786c9c8d9d0d6842ac57a1c83",
            "TextDecoder.mlmodelc/weights/weight.bin":
                "283878d285cb0e557eeb1c6a1524eb5fd33cae2c289a114bc9e72ca76c0bfc75",
        ],
        "large-v3": [
            "config.json": "798b69c08cf93b2b03d94bea6eb3eb25fd4712259712d8a62ed2483fdf818a9e",
            "generation_config.json":
                "d24f9cca0f448609a71ae044b736023706382f45e9700e0dffb2559d10cf1fea",
            "AudioEncoder.mlmodelc/model.mlmodel":
                "bf0987c0d8c3fe180877b12ba5b4ac1d890e011f2103926e53186089feced575",
            "AudioEncoder.mlmodelc/weights/weight.bin":
                "eb07bab32dcd62ce653b5b288bd6c27bdc5a538be309f242e33ed05e1cb53457",
            "MelSpectrogram.mlmodelc/weights/weight.bin":
                "97a66b915cd3fc97dcba6806d92381e1a56024b8f68c1a1cd370d4c92505fe87",
            "TextDecoder.mlmodelc/model.mlmodel":
                "680d8dfb7c7d8f1f852071ac7bdc96e55c696d0b822e70861045efb426b0a27b",
            "TextDecoder.mlmodelc/weights/weight.bin":
                "680f398925225a313c62da0221aa0a58c9f1bffac5c36f20c449a70a7c9b1e55",
        ],
    ]
}
