import SwiftUI

struct SettingsView: View {
    @AppStorage(ModelConfig.selectedModelNameKey) private var selectedModelName: String = "base"

    var body: some View {
        Form {
            Section("WhisperKit") {
                Picker("Model", selection: $selectedModelName) {
                    ForEach(ModelConfig.availableModelNames, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                Text("Models are downloaded automatically by WhisperKit on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Cache location: \(ModelConfig.whisperKitDownloadBaseURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }
}
