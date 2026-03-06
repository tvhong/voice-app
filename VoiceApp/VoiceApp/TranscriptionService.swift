import AppKit
import SwiftWhisper

class TranscriptionService {
    private var whisper: Whisper?
    private var loadedModelURL: URL?

    func transcribe(audioFrames: [Float]) async throws -> String {
        let modelURL = try ModelConfig.resolveModelURL()
        if whisper == nil || loadedModelURL != modelURL {
            whisper = Whisper(fromFileURL: modelURL)
            loadedModelURL = modelURL
        }
        let segments = try await whisper!.transcribe(audioFrames: audioFrames)
        let text = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        return text
    }

}
