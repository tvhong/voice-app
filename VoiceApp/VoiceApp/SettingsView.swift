import SwiftUI
import WhisperKit

struct SettingsView: View {
    @AppStorage(ModelConfig.selectedModelNameKey) private var selectedModelName: String = "base"
    @State private var isDownloadingModel = false
    @State private var downloadProgress: Double = 0
    @State private var downloadStatus = ""
    @State private var downloadError = ""
    @State private var downloadTask: Task<Void, Never>?
    @State private var activeDownloadID: UUID?

    private var isPrepared: Bool {
        WhisperKitModelStore.isModelPrepared(selectedModelName)
    }

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
                Text("To avoid a slow first transcription, download the selected model now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Estimated download size: \(WhisperKitModelStore.estimatedDownloadSize(for: selectedModelName))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Cache location: \(WhisperKitModelStore.downloadBaseURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack {
                    Text("Selected model status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isPrepared ? "Ready" : "Not downloaded")
                        .foregroundStyle(isPrepared ? .green : .secondary)
                }

                HStack(spacing: 8) {
                    Button(isDownloadingModel ? "Downloading..." : "Download Selected Model") {
                        startDownload()
                    }
                    .disabled(isDownloadingModel)

                    if isDownloadingModel {
                        Button("Cancel") {
                            cancelDownload()
                        }
                        .foregroundStyle(.red)

                        ProgressView(value: downloadProgress)
                            .frame(width: 140)
                    }
                }

                if !downloadStatus.isEmpty {
                    Text(downloadStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !downloadError.isEmpty {
                    Text(downloadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: selectedModelName) {
            downloadStatus = ""
            downloadError = ""
            downloadProgress = 0
        }
        .onDisappear {
            cancelDownload()
        }
    }

    private func startDownload() {
        guard !isDownloadingModel else { return }

        isDownloadingModel = true
        downloadProgress = 0
        downloadError = ""
        downloadStatus = "Starting download for \(selectedModelName)..."

        let model = selectedModelName
        let downloadID = UUID()
        activeDownloadID = downloadID
        downloadTask = Task {
            do {
                _ = try await WhisperKit.download(
                    variant: model,
                    downloadBase: WhisperKitModelStore.downloadBaseURL
                ) { progress in
                    Task { @MainActor in
                        guard activeDownloadID == downloadID else { return }
                        if progress.totalUnitCount > 0 {
                            downloadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        }
                        let percent = Int(downloadProgress * 100)
                        downloadStatus = "Downloading \(model)... \(percent)%"
                    }
                }

                await MainActor.run {
                    guard activeDownloadID == downloadID else { return }
                    if Task.isCancelled {
                        downloadStatus = "Download canceled."
                        downloadError = ""
                        isDownloadingModel = false
                        downloadTask = nil
                        activeDownloadID = nil
                        return
                    }
                    downloadProgress = 1
                    downloadStatus = WhisperKitModelStore.isModelPrepared(model)
                        ? "\(model) is downloaded and ready."
                        : "\(model) download incomplete. Please retry."
                    isDownloadingModel = false
                    downloadTask = nil
                    activeDownloadID = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard activeDownloadID == downloadID else { return }
                    downloadStatus = "Download canceled."
                    downloadError = ""
                    isDownloadingModel = false
                    downloadTask = nil
                    activeDownloadID = nil
                }
            } catch {
                await MainActor.run {
                    guard activeDownloadID == downloadID else { return }
                    downloadError = "Download failed: \(error.localizedDescription)"
                    downloadStatus = ""
                    isDownloadingModel = false
                    downloadTask = nil
                    activeDownloadID = nil
                }
            }
        }
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloadingModel = false
        activeDownloadID = nil
        downloadStatus = "Download canceled."
    }
}
