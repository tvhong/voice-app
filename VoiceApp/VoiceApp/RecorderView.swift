import SwiftUI

struct RecorderView: View {
    @State private var recorder = AudioRecorder()
    @State private var isRecording = false
    @State private var sampleCount: Int? = nil
    @State private var maxAmplitude: Float? = nil

    var body: some View {
        VStack(spacing: 16) {
            Button(isRecording ? "Stop" : "Record") {
                if isRecording {
                    let samples = recorder.stopRecording()
                    sampleCount = samples.count
                    maxAmplitude = samples.map(abs).max()
                    print("Samples: \(samples.count), Max amplitude: \(maxAmplitude ?? 0)")
                } else {
                    try? recorder.startRecording()
                }
                isRecording.toggle()
            }

            if let count = sampleCount, let amp = maxAmplitude {
                Text("Samples: \(count)")
                Text("Max amplitude: \(amp, specifier: "%.4f")")
            }
        }
        .padding()
    }
}
