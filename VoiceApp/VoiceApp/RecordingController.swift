import AVFoundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.voiceapp", category: "recording")

enum AppState: Equatable {
    case loading
    case idle
    case recording
    case transcribing
    case done(text: String)
    case error(message: String)
}

@Observable
class RecordingController {
    var state: AppState = .loading
    let history = TranscriptionHistory()
    private var recorder = AudioRecorder()
    private var transcriber = TranscriptionService()

    /// Called when a segment is transcribed during continuous mode (toggle with silence detection).
    var onSegmentTranscribed: ((String) -> Void)?

    func preloadModel() async {
        state = .loading
        do {
            try await transcriber.loadModel()
            state = .idle
        } catch {
            logger.error("Failed to preload model: \(error.localizedDescription)")
            state = .idle  // still allow usage; model will retry on first transcription
        }
    }

    func startRecording() async {
        guard state != .recording, state != .loading else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            state = .error(message: "Microphone access denied")
            return
        }
        do {
            try recorder.startRecording()
            state = .recording
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func stopAndTranscribe() async {
        guard state == .recording else { return }
        let stopTime = Date()
        let frames = recorder.stopRecording()
        state = .transcribing
        do {
            let text = try await transcriber.transcribe(audioFrames: frames)
            let totalTime = Date().timeIntervalSince(stopTime)
            logger.info("total latency (stop → pasted): \(String(format: "%.2f", totalTime))s")
            history.add(text)
            state = .done(text: text)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    /// Start recording with silence-triggered transcription (for toggle mode).
    func startContinuousRecording() async {
        guard state != .recording, state != .loading else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            state = .error(message: "Microphone access denied")
            return
        }
        do {
            recorder.silenceTimeoutDuration = 2.0
            recorder.onSilenceTimeout = { [weak self] in
                guard let self else { return }
                Task { await self.transcribeCurrentSegment() }
            }
            try recorder.startRecording()
            state = .recording
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    /// Drain accumulated audio, transcribe it, and continue recording.
    func transcribeCurrentSegment() async {
        guard state == .recording else { return }
        let frames = recorder.drainSamples()
        guard !frames.isEmpty else { return }

        // Stay in .recording state — don't switch to .transcribing
        // so the user sees we're still listening
        do {
            let text = try await transcriber.transcribe(audioFrames: frames)
            guard !text.isEmpty else { return }
            history.add(text)
            onSegmentTranscribed?(text)
        } catch {
            logger.error("Segment transcription failed: \(error.localizedDescription)")
        }
    }

    /// Stop continuous recording and transcribe any remaining audio.
    func stopContinuousRecording() async {
        guard state == .recording else { return }
        let frames = recorder.stopRecording()
        guard !frames.isEmpty else {
            state = .idle
            return
        }
        state = .transcribing
        do {
            let text = try await transcriber.transcribe(audioFrames: frames)
            if !text.isEmpty {
                history.add(text)
                onSegmentTranscribed?(text)
            }
            state = .done(text: text)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func toggleRecording() async {
        switch state {
        case .idle, .done, .error:
            state = .idle
            await startRecording()
        case .recording:
            await stopAndTranscribe()
        case .loading, .transcribing:
            break
        }
    }
}
