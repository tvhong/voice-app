import SwiftUI

struct FloatingMicView: View {
    var controller: RecordingController
    var onSettingsOpen: () -> Void

    var body: some View {
        ZStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)

            stateOverlay
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
    private var stateOverlay: some View {
        switch controller.state {
        case .idle, .done, .error:
            EmptyView()

        case .recording:
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.red)
                .shadow(color: .black.opacity(0.5), radius: 2)

        case .transcribing:
            Image(systemName: "ellipsis")
                .font(.title2)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .symbolEffect(.variableColor.iterative)
        }
    }
}
