import Foundation
import Observation

struct TranscriptionRecord: Identifiable {
    let id = UUID()
    let text: String
    let date: Date
}

@Observable
class TranscriptionHistory {
    var records: [TranscriptionRecord] = []

    func add(_ text: String) {
        records.insert(TranscriptionRecord(text: text, date: .now), at: 0)
    }
}
