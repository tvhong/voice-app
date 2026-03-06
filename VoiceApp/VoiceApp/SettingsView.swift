import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage(ModelConfig.customModelPathKey) private var customModelPath: String = ""

    private var modelURL: URL {
        customModelPath.isEmpty ? ModelConfig.appSupportModelURL : URL(fileURLWithPath: customModelPath)
    }

    private var modelExists: Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }

    var body: some View {
        Form {
            Section("Whisper Model") {
                HStack {
                    Image(systemName: modelExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(modelExists ? .green : .red)
                    Text(modelExists ? "Model found" : "Model not found")
                    Spacer()
                    if !customModelPath.isEmpty {
                        Button("Reset") {
                            customModelPath = ""
                            ModelConfig.customModelURL = nil
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    Button("Choose…") { pickModel() }
                        .buttonStyle(.borderless)
                }
                Text(modelURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
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
