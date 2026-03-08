import SwiftUI

struct FloatingMicView: View {
    var controller: RecordingController
    var onSettingsOpen: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

            stateIcon
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
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
    private var stateIcon: some View {
        switch controller.state {
        case .idle, .done, .error:
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)

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
