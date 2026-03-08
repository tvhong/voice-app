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
                .fill(RadialGradient(
                    colors: [Color(hex: "#1e5f73"), Color(hex: "#031f3f")],
                    center: UnitPoint(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: 36
                ))
                .padding(4)
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
                .foregroundStyle(Color(hex: "#cfe9ea"))
        case .transcribing:
            Image(systemName: "ellipsis")
                .font(.title2)
                .foregroundStyle(Color(hex: "#cfe9ea"))
                .symbolEffect(.variableColor.iterative)
        }
    }
}
