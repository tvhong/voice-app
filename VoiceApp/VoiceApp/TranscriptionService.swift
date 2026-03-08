import AppKit
import SwiftWhisper

class TranscriptionService {
    private var whisper: Whisper?
    private var loadedModelURL: URL?

    func transcribe(audioFrames: [Float]) async throws -> String {
        let modelURL = try ModelConfig.resolveModelURL()
        if whisper == nil || loadedModelURL != modelURL {
            let params = WhisperParams(strategy: .greedy)
            params.single_segment = true
            params.print_progress = false
            params.print_timestamps = false
            params.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
            whisper = Whisper(fromFileURL: modelURL, withParams: params)
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
