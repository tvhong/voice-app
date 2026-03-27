/// Post-processes raw transcription text.
///
/// Runs two stages in order:
///   1. Cleanup  — strips Whisper artifact tokens like [BLANK_AUDIO]
///   2. Corrections — replaces mis-transcribed terms with the right spelling
///
/// To add a term correction, append an entry to `corrections`.
struct TranscriptionPostProcessor {

    // MARK: - Stage 1: Whisper artifact cleanup

    /// Removes bracketed tokens emitted by Whisper, e.g. [BLANK_AUDIO], [Background Sounds].
    private static let bracketedTokenPattern = /\[.*?\]/

    // MARK: - Stage 2: Term corrections
    //
    // Key:   regex pattern to match (case-insensitive)
    // Value: replacement string
    //
    // Tips:
    //   • Use \b word-boundary anchors to avoid partial-word matches.
    //   • Capture groups in the pattern can be referenced in the replacement.

    private static let corrections: [(pattern: String, replacement: String)] = [
        // Example entries — add your own below:
        // (pattern: #"\bwhisper\s+kit\b"#, replacement: "WhisperKit"),
        // (pattern: #"\bx\s*code\b"#,      replacement: "Xcode"),
        (pattern: #"\bcloud\s+code\b"#, replacement: "Claude Code"),
    ]

    // MARK: - Public API

    /// Runs all post-processing stages on `text` and returns the result.
    static func process(_ text: String) -> String {
        let cleaned = text
            .replacing(bracketedTokenPattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return corrections.reduce(cleaned) { current, entry in
            (try? current.replacing(
                Regex(entry.pattern).ignoresCase(),
                with: entry.replacement
            )) ?? current
        }
    }
}
