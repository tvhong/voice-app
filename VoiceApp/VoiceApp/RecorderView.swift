import AVFoundation
import SwiftUI

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    case done(text: String)
    case error(message: String)
}

struct RecorderView: View {
    @State private var state: AppState = .idle
    @State private var recorder = AudioRecorder()
    @State private var transcriber = TranscriptionService()

    var body: some View {
        VStack(spacing: 16) {
            statusLabel
            actionButton

            if case .done(let text) = state {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 280)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .idle:
            Label("Ready to record", systemImage: "mic")
        case .recording:
            Label("Recording...", systemImage: "waveform")
                .symbolEffect(.variableColor.iterative)
                .foregroundStyle(.red)
        case .transcribing:
            Label("Transcribing...", systemImage: "ellipsis")
                .symbolEffect(.variableColor.iterative)
        case .done:
            Label("Copied to clipboard", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle, .done, .error:
            Button("Start Recording") {
                state = .idle
                Task { await startRecording() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        case .recording:
            Button("Stop & Transcribe") {
                Task { await stopAndTranscribe() }
            }
            .buttonStyle(.borderedProminent)

        case .transcribing:
            Button("Cancel", action: {})
                .disabled(true)
        }
    }

    private func startRecording() async {
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

    private func stopAndTranscribe() async {
        let frames = recorder.stopRecording()
        state = .transcribing
        do {
            let text = try await transcriber.transcribe(audioFrames: frames)
            state = .done(text: text)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
}
