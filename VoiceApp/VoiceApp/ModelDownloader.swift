import Foundation

struct ModelOption: Identifiable {
    let id: String  // filename
    let label: String
    let description: String

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(id)")!
    }

    var destURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("VoiceApp/\(id)")
    }
}

let modelOptions: [ModelOption] = [
    ModelOption(id: "ggml-tiny.en.bin",      label: "tiny.en",      description: "39 MB · Fastest, lower accuracy"),
    ModelOption(id: "ggml-tiny.en-q5_1.bin", label: "tiny.en-q5",   description: "32 MB · Fastest, quantized"),
    ModelOption(id: "ggml-base.en-q5_0.bin", label: "base.en-q5",   description: "57 MB · Good balance — recommended"),
    ModelOption(id: "ggml-base.en-q8_0.bin", label: "base.en-q8",   description: "75 MB · Near-lossless, still faster than base"),
    ModelOption(id: "ggml-base.en.bin",      label: "base.en",      description: "74 MB · Default accuracy"),
]

@Observable
final class ModelDownloader: NSObject {
    enum DownloadState {
        case notDownloaded
        case downloading(Double)
        case downloaded
        case error(String)
    }

    private(set) var states: [String: DownloadState] = [:]
    private var session: URLSession!
    private var taskToFilename: [URLSessionTask: String] = [:]

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        refresh()
    }

    func refresh() {
        for option in modelOptions {
            guard case .downloading = states[option.id] else {
                let exists = FileManager.default.fileExists(atPath: option.destURL.path)
                states[option.id] = exists ? .downloaded : .notDownloaded
                continue
            }
        }
    }

    func download(_ option: ModelOption) {
        guard case .notDownloaded = states[option.id] else { return }
        states[option.id] = .downloading(0)
        let task = session.downloadTask(with: option.downloadURL)
        taskToFilename[task] = option.id
        task.resume()
    }

    func cancel(_ option: ModelOption) {
        if let task = taskToFilename.first(where: { $0.value == option.id })?.key {
            task.cancel()
            taskToFilename.removeValue(forKey: task)
        }
        states[option.id] = .notDownloaded
    }

    func delete(_ option: ModelOption) {
        try? FileManager.default.removeItem(at: option.destURL)
        states[option.id] = .notDownloaded
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let filename = taskToFilename[downloadTask], totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.states[filename] = .downloading(progress) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let filename = taskToFilename[downloadTask],
              let option = modelOptions.first(where: { $0.id == filename })
        else { return }
        taskToFilename.removeValue(forKey: downloadTask)

        do {
            let dir = option.destURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: option.destURL.path) {
                try FileManager.default.removeItem(at: option.destURL)
            }
            try FileManager.default.moveItem(at: location, to: option.destURL)
            DispatchQueue.main.async { self.states[filename] = .downloaded }
        } catch {
            DispatchQueue.main.async { self.states[filename] = .error(error.localizedDescription) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let filename = taskToFilename[task] else { return }
        taskToFilename.removeValue(forKey: task)
        DispatchQueue.main.async { self.states[filename] = .error(error.localizedDescription) }
    }
}
