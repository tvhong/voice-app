import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(ModelConfig.customModelPathKey) private var customModelPath: String = ""
    @State private var downloader = ModelDownloader()

    private var activeModelURL: URL {
        customModelPath.isEmpty ? ModelConfig.appSupportModelURL : URL(fileURLWithPath: customModelPath)
    }

    var body: some View {
        Form {
            Section("Whisper Model") {
                ForEach(modelOptions) { option in
                    ModelRow(
                        option: option,
                        state: downloader.states[option.id] ?? .notDownloaded,
                        isActive: activeModelURL == option.destURL,
                        onDownload: { downloader.download(option) },
                        onCancel: { downloader.cancel(option) },
                        onDelete: {
                            if activeModelURL == option.destURL { customModelPath = "" }
                            downloader.delete(option)
                        },
                        onActivate: { customModelPath = option.destURL.path }
                    )
                }

                HStack {
                    Text("Custom model")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !customModelPath.isEmpty && !modelOptions.contains(where: { $0.destURL.path == customModelPath }) {
                        Button("Reset") { customModelPath = "" }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    Button("Choose…") { pickModel() }
                        .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { downloader.refresh() }
    }

    private func pickModel() {
        let panel = NSOpenPanel()
        panel.title = "Select Whisper Model"
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            ModelConfig.customModelURL = url
            customModelPath = url.path
        }
    }
}

private struct ModelRow: View {
    let option: ModelOption
    let state: ModelDownloader.DownloadState
    let isActive: Bool
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Active indicator
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .onTapGesture {
                    if case .downloaded = state { onActivate() }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.label).fontWeight(isActive ? .semibold : .regular)
                Text(option.description).font(.caption).foregroundStyle(.secondary)
                if case .downloading(let progress) = state {
                    ProgressView(value: progress).frame(maxWidth: 160)
                }
                if case .error(let msg) = state {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer()

            switch state {
            case .notDownloaded:
                Button("Download", action: onDownload).buttonStyle(.bordered)
            case .downloading:
                Button("Cancel", action: onCancel).buttonStyle(.bordered).foregroundStyle(.secondary)
            case .downloaded:
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            case .error:
                Button("Retry", action: onDownload).buttonStyle(.borderless).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .downloaded = state { onActivate() }
        }
    }
}
