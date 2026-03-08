import SwiftUI

struct FloatingMicView: View {
    var controller: RecordingController
    var onSettingsOpen: () -> Void

    var body: some View {
        ZStack {
            background
            foregroundIcon
        }
        .frame(width: 56, height: 56)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await controller.toggleRecording() }
        }
        .contextMenu {
            Button("Settings", action: onSettingsOpen)
            Divider()
            Button("Quit VoiceApp") { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch controller.state {
        case .idle, .done, .error:
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
        case .recording, .transcribing:
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var foregroundIcon: some View {
        switch controller.state {
        case .idle, .done, .error:
            EmptyView()
        case .recording:
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.red)
        case .transcribing:
            Image(systemName: "ellipsis")
                .font(.title2)
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative)
        }
    }
}
