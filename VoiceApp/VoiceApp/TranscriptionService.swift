import AppKit
import SwiftWhisper

class TranscriptionService {
    private var whisper: Whisper?

    func transcribe(audioFrames: [Float]) async throws -> String {
        if whisper == nil {
            let modelURL = try resolveModelURL()
            whisper = Whisper(fromFileURL: modelURL)
        }
        let segments = try await whisper!.transcribe(audioFrames: audioFrames)
        let text = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        return text
    }

    private func resolveModelURL() throws -> URL {
        let appSupportURL = ModelConfig.appSupportModelURL
        if FileManager.default.fileExists(atPath: appSupportURL.path) {
            return appSupportURL
        }

        if let bundleURL = Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") {
            return bundleURL
        }

        throw TranscriptionError.modelNotFound(expectedPath: appSupportURL.path)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotFound(expectedPath: String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Whisper model not found. Download it to:\n\(path)"
        }
    }
}
