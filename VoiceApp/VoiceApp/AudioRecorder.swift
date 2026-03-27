import AVFoundation

@Observable final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var capturedSamples: [Float] = []

    /// Called on the main thread when continuous silence exceeds the timeout.
    var onSilenceTimeout: (() -> Void)?

    /// Duration of silence (in seconds) before `onSilenceTimeout` fires. 0 = disabled.
    var silenceTimeoutDuration: TimeInterval = 0

    /// RMS threshold below which audio is considered silence.
    private let silenceThreshold: Float = 0.01

    /// Timestamp of last detected speech audio.
    private var lastSpeechDate: Date = .distantPast

    /// Whether the silence callback has already fired for the current silent stretch.
    private var silenceCallbackFired = false

    /// Whether any speech has been detected since the last drain/start.
    private var speechDetectedSinceDrain = false

    func startRecording() throws {
        capturedSamples = []
        lastSpeechDate = Date()
        silenceCallbackFired = false
        speechDetectedSinceDrain = false

        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)   // no-op if no tap; prevents crash on rapid re-trigger
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: nativeFormat, to: whisperFormat) else {
            throw AudioError.converterSetupFailed
        }
        converter = conv

        let ratio = 16000.0 / nativeFormat.sampleRate

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) {
            [weak self] buffer, _ in
            self?.process(buffer: buffer, ratio: ratio)
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        silenceTimeoutDuration = 0
        onSilenceTimeout = nil
        return capturedSamples
    }

    /// Returns accumulated samples and resets the buffer without stopping recording.
    func drainSamples() -> [Float] {
        let samples = capturedSamples
        capturedSamples = []
        lastSpeechDate = Date()
        silenceCallbackFired = false
        speechDetectedSinceDrain = false
        return samples
    }

    private func process(buffer: AVAudioPCMBuffer, ratio: Double) {
        guard let converter else { return }

        let inputFrames = AVAudioFrameCount(buffer.frameLength)
        let outputCapacity = AVAudioFrameCount(Double(inputFrames) * ratio + 1)  // +1 to ensure sufficient buffer

        guard
            let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: whisperFormat,
                frameCapacity: outputCapacity
            )
        else { return }

        // The simpler convert(to:from:) overload requires outputCapacity >= inputFrames,
        // which fails when downsampling (output is smaller than input). The closure-based
        // API handles this correctly.
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
            let channelData = outputBuffer.floatChannelData
        else { return }

        let frameCount = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.capturedSamples.append(contentsOf: samples)
            self.checkSilence(samples: samples)
        }
    }

    private func checkSilence(samples: [Float]) {
        guard silenceTimeoutDuration > 0 else { return }

        // Compute RMS of the chunk
        let sumSq = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumSq / Float(max(samples.count, 1))).squareRoot()

        if rms >= silenceThreshold {
            lastSpeechDate = Date()
            silenceCallbackFired = false
            speechDetectedSinceDrain = true
        } else if speechDetectedSinceDrain,
                  !silenceCallbackFired,
                  Date().timeIntervalSince(lastSpeechDate) >= silenceTimeoutDuration {
            silenceCallbackFired = true
            onSilenceTimeout?()
        }
    }

    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!
}

enum AudioError: Error {
    case converterSetupFailed
}
