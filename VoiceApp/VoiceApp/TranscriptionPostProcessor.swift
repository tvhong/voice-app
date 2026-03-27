/// Post-processes raw transcription text by applying a dictionary of corrections.
///
/// Add entries to `corrections` to fix terms that Whisper consistently mis-transcribes.
/// Each key is a regex pattern (case-insensitive) and the value is its replacement.
///
/// Example:
///   "whisper kit" → "WhisperKit"
///   "x code"      → "Xcode"
struct TranscriptionPostProcessor {

    // MARK: - Corrections dictionary
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

    /// Applies all corrections to `text` and returns the result.
    static func process(_ text: String) -> String {
        corrections.reduce(text) { current, entry in
            (try? current.replacing(
                Regex(entry.pattern).ignoresCase(),
                with: entry.replacement
            )) ?? current
        }
    }
}
