import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Whisper Model") {
                HStack {
                    Image(systemName: modelExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(modelExists ? .green : .red)
                    Text(modelExists ? "Model found" : "Model not found")
                }
                Text(modelPath.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !modelExists {
                    Text("Run the download command in README.md to install the model.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    private var modelPath: URL {
        ModelConfig.appSupportModelURL
    }

    private var modelExists: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }
}
