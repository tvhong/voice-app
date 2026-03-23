import SwiftUI
import WhisperKit

struct SettingsView: View {
    @AppStorage(HotkeyConfig.keyKey) private var hotkeyKey: String = HotkeyKey.commandD.rawValue
    @AppStorage(HotkeyConfig.modeKey) private var hotkeyMode: String = HotkeyMode.toggle.rawValue
    @AppStorage(ModelConfig.selectedModelNameKey) private var selectedModelName: String = "base"
    @State private var isDownloadingModel = false
    @State private var downloadingModelName: String?
    @State private var downloadProgress: Double = 0
    @State private var downloadStatus = ""
    @State private var downloadError = ""
    @State private var downloadTask: Task<Void, Never>?
    @State private var activeDownloadID: UUID?
    @State private var modelPendingDeletion: String?

    private var deleteDialogTitle: String {
        if let modelPendingDeletion {
            return "Delete \(modelPendingDeletion)?"
        }
        return "Delete downloaded model?"
    }

    var body: some View {
        Form {
            Section("Hotkey") {
                Picker("Key", selection: $hotkeyKey) {
                    ForEach(HotkeyKey.allCases, id: \.rawValue) { key in
                        Text(key.label).tag(key.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Mode", selection: $hotkeyMode) {
                    ForEach(HotkeyMode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("WhisperKit") {
                VStack(spacing: 8) {
                    ForEach(ModelConfig.availableModelNames, id: \.self) { model in
                        modelRow(for: model)
                    }
                }

                Text(
                    "Models are downloaded automatically by WhisperKit on first use.\nCache location: \(WhisperKitModelStore.downloadBaseURL.path)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

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
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { modelPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        modelPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: modelPendingDeletion
        ) { model in
            Button(role: .destructive) {
                deleteModel(model)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("This will remove local files for \(model) to free disk space.")
        }
    }

    @ViewBuilder
    private func modelRow(for model: String) -> some View {
        let isSelected = model == selectedModelName
        let isPrepared = WhisperKitModelStore.isModelPrepared(model)
        let isDownloadingThisModel = isDownloadingModel && downloadingModelName == model

        HStack(spacing: 12) {
            Button {
                selectedModelName = model
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model)
                        Text(WhisperKitModelStore.estimatedDownloadSize(for: model))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()

            if isPrepared {
                HStack(spacing: 8) {
                    Button {
                        modelPendingDeletion = model
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .disabled(isDownloadingModel)
                }
            } else if isDownloadingThisModel {
                HStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .frame(width: 90)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        cancelDownload()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            } else {
                Button {
                    startDownload(for: model)
                } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Download \(model)")
                .disabled(isDownloadingModel)
            }
        }
    }

    private func startDownload(for model: String) {
        guard !isDownloadingModel else { return }

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
                            downloadProgress =
                                Double(progress.completedUnitCount)
                                / Double(progress.totalUnitCount)
                        }
                        let percent = Int(downloadProgress * 100)
                        downloadStatus = "Downloading \(model)... \(percent)%"
                    }
                }

                let isVerified = WhisperKitModelStore.verifyAndMarkModel(model)
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
                    downloadStatus =
                        isVerified
                        ? "\(model) is downloaded and ready."
                        : "\(model) failed integrity verification. Please retry."
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

    private func deleteModel(_ model: String) {
        do {
            try WhisperKitModelStore.deleteModel(model)
            downloadError = ""
            downloadStatus = "\(model) deleted."
            modelPendingDeletion = nil
        } catch {
            downloadStatus = ""
            downloadError = "Delete failed: \(error.localizedDescription)"
            modelPendingDeletion = nil
        }
    }
}
