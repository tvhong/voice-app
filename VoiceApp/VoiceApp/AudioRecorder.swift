import AVFoundation

@Observable final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var capturedSamples: [Float] = []

    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func startRecording() throws {
        capturedSamples = []

        let inputNode = engine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: nativeFormat, to: whisperFormat) else {
            throw AudioError.converterSetupFailed
        }
        converter = conv

        let ratio = 16000.0 / nativeFormat.sampleRate

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer, ratio: ratio)
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return capturedSamples
    }

    private func process(buffer: AVAudioPCMBuffer, ratio: Double) {
        guard let converter else { return }

        let inputFrames = AVAudioFrameCount(buffer.frameLength)
        let outputCapacity = AVAudioFrameCount(Double(inputFrames) * ratio + 1)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: whisperFormat,
            frameCapacity: outputCapacity
        ) else { return }

        var inputConsumed = false
        let status = converter.convert(to: outputBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error,
              let channelData = outputBuffer.floatChannelData else { return }

        let frameCount = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        DispatchQueue.main.async { [weak self] in
            self?.capturedSamples.append(contentsOf: samples)
        }
    }
}

enum AudioError: Error {
    case converterSetupFailed
}
