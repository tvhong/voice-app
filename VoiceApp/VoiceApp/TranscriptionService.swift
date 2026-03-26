import OSLog
import WhisperKit

private let logger = Logger(subsystem: "com.voiceapp", category: "transcription")

class TranscriptionService {
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    func loadModel() async throws {
        let modelName = ModelConfig.selectedModelName
        if whisperKit == nil || loadedModelName != modelName {
            logger.info("Preloading model: \(modelName)")
            let config = WhisperKitModelStore.makeConfig(model: modelName)
            whisperKit = try await WhisperKit(config)
            loadedModelName = modelName
            logger.info("Model loaded: \(modelName)")
        }
    }

    func transcribe(audioFrames: [Float]) async throws -> String {
        try await loadModel()

        let rawDuration = Double(audioFrames.count) / 16000
        let trimmed = trimSilence(audioFrames)
        let framesForInference = trimmed.isEmpty ? audioFrames : trimmed
        let trimmedDuration = Double(framesForInference.count) / 16000
        let trimmedFrames = audioFrames.count - framesForInference.count
        logger.info("audio: \(String(format: "%.2f", rawDuration))s -> trimmed to \(String(format: "%.2f", trimmedDuration))s (\(trimmedFrames) frames removed)")

        let inferenceStart = Date()
        guard let whisperKit else {
            throw NSError(domain: "VoiceApp.TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "WhisperKit failed to initialize"])
        }

        let segments = try await whisperKit.transcribe(audioArray: framesForInference)
        let inferenceTime = Date().timeIntervalSince(inferenceStart)
        let rtf = trimmedDuration > 0 ? inferenceTime / trimmedDuration : 0
        logger.info("inference: \(String(format: "%.2f", inferenceTime))s | RTF: \(String(format: "%.2f", rtf))x | model: \(self.loadedModelName ?? "unknown")")

        let text = segments
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    // Strips leading and trailing silence using a 10ms RMS window at 16kHz.
    private func trimSilence(_ frames: [Float], threshold: Float = 0.01, windowSize: Int = 160) -> [Float] {
        guard frames.count >= windowSize else { return frames }

        func rms(_ slice: ArraySlice<Float>) -> Float {
            let sum = slice.reduce(0) { $0 + $1 * $1 }
            return (sum / Float(slice.count)).squareRoot()
        }

        var start = 0
        var i = 0
        while i + windowSize <= frames.count {
            if rms(frames[i..<i + windowSize]) >= threshold {
                start = i
                break
            }
            i += windowSize
        }

        var end = frames.count
        var j = frames.count - windowSize
        while j >= 0 {
            if rms(frames[j..<j + windowSize]) >= threshold {
                end = j + windowSize
                break
            }
            j -= windowSize
        }

        guard start < end else { return frames }
        return Array(frames[start..<end])
    }
}
