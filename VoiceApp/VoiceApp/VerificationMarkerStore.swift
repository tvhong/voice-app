import Foundation

struct VerificationMarkerStore {
    static func hasValidMarker(
        for model: String,
        modelFolder: URL,
        manifest: [String: String],
        manifestRevision: String,
        downloadBaseURL: URL
    ) -> Bool {
        let markerURL = markerURL(for: model, downloadBaseURL: downloadBaseURL)
        print("[Marker] Checking marker at \(markerURL.path)")

        guard let data = try? Data(contentsOf: markerURL) else {
            print("[Marker] No marker file found")
            return false
        }

        guard let marker = try? JSONDecoder().decode(VerificationMarker.self, from: data) else {
            print("[Marker] Failed to decode marker JSON")
            return false
        }

        guard marker.manifestRevision == manifestRevision else {
            print("[Marker] Revision mismatch — marker: '\(marker.manifestRevision)', expected: '\(manifestRevision)'")
            return false
        }

        for relativePath in manifest.keys {
            guard let expected = marker.fingerprints[relativePath] else {
                print("[Marker] No fingerprint in marker for '\(relativePath)'")
                return false
            }
            guard let current = currentFingerprint(for: modelFolder.appendingPathComponent(relativePath)) else {
                print("[Marker] Could not read current fingerprint for '\(relativePath)'")
                return false
            }
            guard current == expected else {
                print("[Marker] Fingerprint changed for '\(relativePath)' — size: \(current.size) vs \(expected.size), modifiedAt: \(current.modifiedAt) vs \(expected.modifiedAt)")
                return false
            }
        }

        return true
    }

    static func writeMarker(
        for model: String,
        manifestRevision: String,
        fingerprints: [String: FileFingerprint],
        downloadBaseURL: URL
    ) {
        let markerURL = markerURL(for: model, downloadBaseURL: downloadBaseURL)
        let markerDir = markerURL.deletingLastPathComponent()
        let marker = VerificationMarker(manifestRevision: manifestRevision, fingerprints: fingerprints)

        do {
            try FileManager.default.createDirectory(at: markerDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(marker)
            try data.write(to: markerURL, options: .atomic)
        } catch {
            print("[Marker] Failed to write marker: \(error)")
        }
    }

    static func removeMarker(for model: String, downloadBaseURL: URL) {
        try? FileManager.default.removeItem(at: markerURL(for: model, downloadBaseURL: downloadBaseURL))
    }

    static func currentFingerprint(for fileURL: URL) -> FileFingerprint? {
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

    private static func markerURL(for model: String, downloadBaseURL: URL) -> URL {
        downloadBaseURL
            .appendingPathComponent("verification", isDirectory: true)
            .appendingPathComponent("\(model).json")
    }

    private struct VerificationMarker: Codable {
        let manifestRevision: String
        let fingerprints: [String: FileFingerprint]
    }

    struct FileFingerprint: Codable, Equatable {
        let size: Int64
        let modifiedAt: TimeInterval
    }
}
