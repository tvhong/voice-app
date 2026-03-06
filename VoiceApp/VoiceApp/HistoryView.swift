import SwiftUI

struct HistoryView: View {
    @Environment(TranscriptionHistory.self) var history

    var body: some View {
        if history.records.isEmpty {
            ContentUnavailableView("No Transcriptions", systemImage: "mic.slash")
        } else {
            List(history.records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.text)
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}
