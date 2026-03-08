import SwiftUI
import WhisperKit

struct SettingsView: View {
    @AppStorage(ModelConfig.selectedModelNameKey) private var selectedModelName: String = "base"
    @State private var isDownloadingModel = false
    @State private var downloadingModelName: String?
    @State private var downloadProgress: Double = 0
    @State private var downloadStatus = ""
    @State private var downloadError = ""
    @State private var downloadTask: Task<Void, Never>?
    @State private var activeDownloadID: UUID?

    var body: some View {
        Form {
            Section("WhisperKit") {
                VStack(spacing: 8) {
                    ForEach(ModelConfig.availableModelNames, id: \.self) { model in
                        modelRow(for: model)
                    }
                }

                Text("Models are downloaded automatically by WhisperKit on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Estimated download size: \(WhisperKitModelStore.estimatedDownloadSize(for: selectedModelName))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Cache location: \(WhisperKitModelStore.downloadBaseURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

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
            if !isDownloadingModel {
                downloadStatus = ""
                downloadError = ""
                downloadProgress = 0
            }
        }
        .onDisappear {
            cancelDownload()
        }
    }

    @ViewBuilder
    private func modelRow(for model: String) -> some View {
        let isSelected = model == selectedModelName
        let isPrepared = WhisperKitModelStore.isModelPrepared(model)
        let isDownloadingThisModel = isDownloadingModel && downloadingModelName == model

        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(model)
                Text(WhisperKitModelStore.estimatedDownloadSize(for: model))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if isPrepared {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if isDownloadingThisModel {
                HStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 90)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel") {
                        cancelDownload()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            } else {
                Button("Download") {
                    startDownload(for: model)
                }
                .disabled(isDownloadingModel)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedModelName = model
        }
    }

    private func startDownload(for model: String) {
        guard !isDownloadingModel else { return }

        selectedModelName = model
        isDownloadingModel = true
        downloadingModelName = model
        downloadProgress = 0
        downloadError = ""
        downloadStatus = "Starting download for \(model)..."

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
                        downloadingModelName = nil
                        downloadTask = nil
                        activeDownloadID = nil
                        return
                    }
                    downloadProgress = 1
                    downloadStatus = WhisperKitModelStore.isModelPrepared(model)
                        ? "\(model) is downloaded and ready."
                        : "\(model) download incomplete. Please retry."
                    isDownloadingModel = false
                    downloadingModelName = nil
                    downloadTask = nil
                    activeDownloadID = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard activeDownloadID == downloadID else { return }
                    downloadStatus = "Download canceled."
                    downloadError = ""
                    isDownloadingModel = false
                    downloadingModelName = nil
                    downloadTask = nil
                    activeDownloadID = nil
                }
            } catch {
                await MainActor.run {
                    guard activeDownloadID == downloadID else { return }
                    downloadError = "Download failed: \(error.localizedDescription)"
                    downloadStatus = ""
                    isDownloadingModel = false
                    downloadingModelName = nil
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
        downloadingModelName = nil
        activeDownloadID = nil
        downloadStatus = "Download canceled."
    }
}
