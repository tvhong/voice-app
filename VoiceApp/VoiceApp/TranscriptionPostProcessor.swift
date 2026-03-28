import Foundation

struct TranscriptionPostProcessor {

    // Removes Whisper artifact tokens enclosed in brackets, e.g. [BLANK_AUDIO], (music), {noise}.
    private static let artifactTokenPattern = #/
        [\[({]   # opening bracket: [, (, or {
        .*?       # content (non-greedy)
        [\])}]   # closing bracket: ], ), or }
    /#

    // Regex corrections for mis-transcribed terms (case-insensitive).
    // Add entries here: (pattern: #"\bwrong\s+term\b"#, replacement: "Right Term")
    private static let corrections: [(pattern: String, replacement: String)] = [
        (pattern: #"\bcloud\s+code\b"#, replacement: "Claude Code"),
        (pattern: #"\bNK\s+note\b"#, replacement: "Anki note"),
    ]

    static func process(_ text: String) -> String {
        let cleaned = text
            .replacing(artifactTokenPattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return corrections.reduce(cleaned) { current, entry in
            (try? current.replacing(
                Regex(entry.pattern).ignoresCase(),
                with: entry.replacement
            )) ?? current
        }
    }
}
