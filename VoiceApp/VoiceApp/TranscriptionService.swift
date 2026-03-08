import AppKit
import OSLog
import SwiftWhisper

private let logger = Logger(subsystem: "com.voiceapp", category: "transcription")

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

        let rawDuration = Double(audioFrames.count) / 16000
        let trimmed = trimSilence(audioFrames)
        let trimmedDuration = Double(trimmed.count) / 16000
        let trimmedFrames = audioFrames.count - trimmed.count
        logger.info("audio: \(String(format: "%.2f", rawDuration))s → trimmed to \(String(format: "%.2f", trimmedDuration))s (\(trimmedFrames) frames removed)")

        let inferenceStart = Date()
        let segments = try await whisper!.transcribe(audioFrames: trimmed)
        let inferenceTime = Date().timeIntervalSince(inferenceStart)
        let rtf = trimmedDuration > 0 ? inferenceTime / trimmedDuration : 0
        logger.info("inference: \(String(format: "%.2f", inferenceTime))s | RTF: \(String(format: "%.2f", rtf))x | model: \(modelURL.lastPathComponent)")

        let text = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        return text
    }

    // Strips leading and trailing silence using a 10ms RMS window at 16kHz.
    private func trimSilence(_ frames: [Float], threshold: Float = 0.01, windowSize: Int = 160) -> [Float] {
        func rms(_ slice: ArraySlice<Float>) -> Float {
            let sum = slice.reduce(0) { $0 + $1 * $1 }
            return (sum / Float(slice.count)).squareRoot()
        }

        var start = 0
        var i = 0
        while i + windowSize <= frames.count {
            if rms(frames[i..<i + windowSize]) >= threshold { start = i; break }
            i += windowSize
        }

        var end = frames.count
        var j = frames.count - windowSize
        while j >= 0 {
            if rms(frames[j..<j + windowSize]) >= threshold { end = j + windowSize; break }
            j -= windowSize
        }

        guard start < end else { return frames }
        return Array(frames[start..<end])
    }
}
