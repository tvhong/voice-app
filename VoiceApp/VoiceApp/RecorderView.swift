import SwiftUI

struct RecorderView: View {
    var controller: RecordingController

    var body: some View {
        VStack(spacing: 16) {
            statusLabel
            actionButton

            if case .done(let text) = controller.state {
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
        switch controller.state {
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
        switch controller.state {
        case .idle, .done, .error:
            Button("Start Recording") {
                Task { await controller.toggleRecording() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        case .recording:
            Button("Stop & Transcribe") {
                Task { await controller.toggleRecording() }
            }
            .buttonStyle(.borderedProminent)

        case .transcribing:
            Button("Cancel", action: {})
                .disabled(true)
        }
    }
}
