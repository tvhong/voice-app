import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct ModelOption: Identifiable {
    let id: String  // filename
    let label: String
    let description: String

    var downloadURL: String {
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(id)"
    }

    var curlCommand: String {
        let dest = ("~/Library/Application Support/VoiceApp/\(id)" as NSString).expandingTildeInPath
        return "curl -L -o \"\(dest)\" \"\(downloadURL)\""
    }
}

private let modelOptions: [ModelOption] = [
    ModelOption(id: "ggml-tiny.en.bin",     label: "tiny.en (39 MB)",      description: "Fastest, lower accuracy"),
    ModelOption(id: "ggml-tiny.en-q5_1.bin", label: "tiny.en-q5 (32 MB)", description: "Fastest, quantized"),
    ModelOption(id: "ggml-base.en-q5_0.bin", label: "base.en-q5 (57 MB)", description: "Good balance — recommended"),
    ModelOption(id: "ggml-base.en-q8_0.bin", label: "base.en-q8 (75 MB)", description: "Near-lossless, still faster than base"),
]

struct SettingsView: View {
    @AppStorage(ModelConfig.customModelPathKey) private var customModelPath: String = ""
    @State private var selectedModelID = modelOptions[2].id
    @State private var copied = false

    private var modelURL: URL {
        customModelPath.isEmpty ? ModelConfig.appSupportModelURL : URL(fileURLWithPath: customModelPath)
    }

    private var modelExists: Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }

    private var selectedOption: ModelOption {
        modelOptions.first { $0.id == selectedModelID } ?? modelOptions[2]
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

            Section("Download a Faster Model") {
                Picker("Model", selection: $selectedModelID) {
                    ForEach(modelOptions) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                Text(selectedOption.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top) {
                    Text(selectedOption.curlCommand)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(copied ? "Copied!" : "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(selectedOption.curlCommand, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(copied ? Color.secondary : Color.accentColor)
                }

                Text("Run the command in Terminal, then use Choose… above to select the downloaded file.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
