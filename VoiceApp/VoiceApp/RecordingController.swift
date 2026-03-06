import AVFoundation
import Observation

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    case done(text: String)
    case error(message: String)
}

@Observable
class RecordingController {
    var state: AppState = .idle
    private var recorder = AudioRecorder()
    private var transcriber = TranscriptionService()

    func startRecording() async {
        guard state != .recording else { return }
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
        let frames = recorder.stopRecording()
        state = .transcribing
        do {
            let text = try await transcriber.transcribe(audioFrames: frames)
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
        case .transcribing:
            break
        }
    }
}
