import SwiftUI

struct FloatingMicView: View {
    var controller: RecordingController
    var onSettingsOpen: () -> Void

    private let size: CGFloat = 38

    var body: some View {
        ZStack {
            background
            foregroundIcon
        }
        .frame(width: size, height: size)
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
                .frame(width: size, height: size)
        case .recording, .transcribing:
            RoundedRectangle(cornerRadius: 8)
                .fill(RadialGradient(
                    colors: [Color(hex: "#1e5f73"), Color(hex: "#031f3f")],
                    center: UnitPoint(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: size * 0.65
                ))
                .padding(3)
        }
    }

    @ViewBuilder
    private var foregroundIcon: some View {
        switch controller.state {
        case .idle, .done, .error:
            EmptyView()
        case .recording:
            Image(systemName: "mic.fill")
                .font(.body)
                .foregroundStyle(Color(hex: "#cfe9ea"))
                .symbolEffect(.pulse, options: .repeating)
        case .transcribing:
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(Color(hex: "#cfe9ea"))
                .symbolEffect(.variableColor.iterative)
        }
    }
}
