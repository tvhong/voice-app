import Foundation

enum ModelFilesystem {
    static func resolveModelFolder(
        fileManager: FileManager,
        modelsRoot: URL,
        modelSuffix: String
    ) -> URL? {
        guard let enumerator = fileManager.enumerator(
            at: modelsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator {
            guard isDirectory(url) else { continue }
            if url.lastPathComponent.hasSuffix(modelSuffix) {
                return url
            }
        }

        return nil
    }

    static func hasRequiredModelFiles(
        fileManager: FileManager,
        modelFolder: URL,
        requiredModelFiles: [String]
    ) -> Bool {
        hasAllFiles(
            fileManager: fileManager,
            root: modelFolder,
            relativePaths: requiredModelFiles
        )
    }

    static func hasValidTokenizerFilesIfPresent(
        fileManager: FileManager,
        modelsRoot: URL,
        modelSuffix: String,
        requiredTokenizerFiles: [String]
    ) -> Bool {
        let tokenizerFolder = modelsRoot
            .appendingPathComponent("openai", isDirectory: true)
            .appendingPathComponent(modelSuffix, isDirectory: true)

        // Newer WhisperKit layouts may not place tokenizer files in this cache path.
        // If the tokenizer folder is absent, treat the model as prepared.
        guard fileManager.fileExists(atPath: tokenizerFolder.path) else {
            return true
        }

        return hasAllFiles(
            fileManager: fileManager,
            root: tokenizerFolder,
            relativePaths: requiredTokenizerFiles
        )
    }

    private static func hasAllFiles(
        fileManager: FileManager,
        root: URL,
        relativePaths: [String]
    ) -> Bool {
        for relativePath in relativePaths {
            if !fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path) {
                return false
            }
        }
        return true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
