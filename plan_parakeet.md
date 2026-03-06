# Plan: Add Parakeet CTC Model with Model Selection UI

## Context

The app currently uses SwiftWhisper (whisper.cpp) which is slow. We want to add NVIDIA Parakeet CTC 0.6B as a faster alternative, but keep Whisper available. The user can switch between them in Settings.

The `transcribe(audioFrames: [Float]) async throws -> String` API is preserved — no changes to `RecordingController`, `AudioRecorder`, `HotkeyManager`, `RecorderView`, or `AppDelegate`.

Audio format is unchanged: 16kHz mono Float32 (Parakeet uses the same sample rate).

---

## Architecture After Change

```
SettingsView — model picker (Whisper / Parakeet) → stored in UserDefaults
                                                            │
                                                            ▼
TranscriptionService — reads ModelPreference.current ──────┤
    ├── .whisper  →  WhisperTranscription (existing SwiftWhisper path)
    └── .parakeet →  AudioFeatureExtractor → MLModel → CTCDecoder
```

SwiftWhisper dependency is **kept** (needed for Whisper backend).

---

## Files Changed

| File | Status | Notes |
|---|---|---|
| `scripts/convert_parakeet.py` | New | One-time Python script to produce the Core ML model + vocab JSON |
| `VoiceApp/VoiceApp/ModelPreference.swift` | New | `ModelType` enum + UserDefaults storage |
| `VoiceApp/VoiceApp/ModelConfig.swift` | Modified | Add `parakeetAppSupportURL` + `parakeetVocabURL` paths |
| `VoiceApp/VoiceApp/AudioFeatureExtractor.swift` | New | Accelerate/vDSP log-mel spectrogram (no new packages) |
| `VoiceApp/VoiceApp/CTCDecoder.swift` | New | Greedy CTC decode + SentencePiece BPE vocab loading |
| `VoiceApp/VoiceApp/TranscriptionService.swift` | Modified | Route to Whisper or Parakeet backend based on preference |
| `VoiceApp/VoiceApp/SettingsView.swift` | Modified | Add model Picker; show status for both models |
| `README.md` | Modified | Add Parakeet setup instructions alongside existing Whisper instructions |

---

## Task List (one commit per item)

- [ ] **1. Add `scripts/convert_parakeet.py`** — Python script (run once, outside Xcode) that loads `nvidia/parakeet-ctc-0.6b` via NeMo, fuses encoder+decoder into one `nn.Module`, traces with TorchScript, converts to Core ML `.mlpackage` with flexible `RangeDim`, exports BPE vocab as `parakeet-vocab.json`. Both outputs go to `~/Library/Application Support/VoiceApp/`.

- [ ] **2. Add `ModelPreference.swift`** — `ModelType` enum (`.whisper`, `.parakeet`) with `displayName` property. `ModelPreference` enum with `current: ModelType` get/set backed by `UserDefaults` key `"selectedModelType"`. Default is `.whisper`.

- [ ] **3. Update `ModelConfig.swift`** — Add `parakeetAppSupportURL` (→ `parakeet.mlpackage`) and `parakeetVocabURL` (→ `parakeet-vocab.json`) alongside the existing Whisper properties. No removals.

- [ ] **4. Add `AudioFeatureExtractor.swift`** — Compute log-mel spectrogram using `Accelerate`/`vDSP`. Parameters matching Parakeet: n_fft=512, hop=160 (10ms), win=400 (25ms), n_mels=80, sr=16000, fmin=0, fmax=8000. Must use **Slaney-normalised** triangular mel filterbank (matches librosa default). Output: `[[Float]]` shaped `[n_mels][numFrames]`.

- [ ] **5. Add `CTCDecoder.swift`** — Loads `parakeet-vocab.json` from `ModelConfig.parakeetVocabURL`. Greedy argmax over time steps, collapse consecutive duplicates, remove blank (index 1024). Join BPE pieces, replace `▁` (U+2581) with space.

- [ ] **6. Update `TranscriptionService.swift`** — Add `private var loadedModelType: ModelType?` to detect preference changes. On each `transcribe()` call: if preference changed since last call, nil out cached instances. Route to existing Whisper path or new Parakeet path based on `ModelPreference.current`. Parakeet path: lazy-load `MLModel` (`computeUnits = .all`), call `AudioFeatureExtractor`, pack into `MLMultiArray [1, 80, T]`, run prediction in `Task.detached`, call `CTCDecoder`.

- [ ] **7. Update `SettingsView.swift`** — Add `@AppStorage("selectedModelType") var selectedModelType` Picker above the existing Whisper section. Add a second Parakeet section (with `parakeet.mlpackage` status and install instruction). The existing "Choose…" file picker for the Whisper model stays unchanged.

- [ ] **8. Update `README.md`** — Add Parakeet setup section alongside the existing Whisper section.

---

## Key Implementation Details

### `ModelPreference.swift`
```swift
enum ModelType: String, CaseIterable {
    case whisper = "whisper"
    case parakeet = "parakeet"
    var displayName: String { ... }
}
enum ModelPreference {
    static var current: ModelType { get/set via UserDefaults["selectedModelType"] }
}
```

### `TranscriptionService.swift` routing
```swift
private var loadedModelType: ModelType?

func transcribe(audioFrames: [Float]) async throws -> String {
    let preferred = ModelPreference.current
    if preferred != loadedModelType {
        whisper = nil; mlModel = nil; ctcDecoder = nil
        loadedModelType = nil
    }
    switch preferred {
    case .whisper:  return try await transcribeWithWhisper(audioFrames)
    case .parakeet: return try await transcribeWithParakeet(audioFrames)
    }
}
```

### Mel filterbank normalisation (critical for Parakeet accuracy)
Each triangular filter weight must be divided by its bandwidth (Slaney normalisation):
```swift
let norm = 2.0 / (melToHz(melPoints[m + 2]) - melToHz(melPoints[m]))
weight *= norm
```
Without this, transcription quality degrades significantly.

### Core ML tensor names (set in the Python script)
- Input: `"mel_spectrogram"`, shape `[1, 80, T]`, float32
- Output: `"log_probs"`, shape `[1, T', 1025]`, float32 (log-softmax)
- Blank token: index **1024**

### Model switching cache invalidation
`TranscriptionService` tracks `loadedModelType`. When the user switches models in Settings, the next `transcribe()` call detects the change, clears all cached objects (`whisper`, `mlModel`, `ctcDecoder`), and reloads the new backend.

---

## Verification

1. Run `python scripts/convert_parakeet.py` → verify `parakeet.mlpackage` and `parakeet-vocab.json` in `~/Library/Application Support/VoiceApp/`
2. Build in Xcode — no errors
3. Open Settings → Picker shows "Whisper" and "Parakeet CTC 0.6B"
4. With Whisper selected: press Fn, speak, release → correct transcript (existing behaviour)
5. Switch to Parakeet in Settings
6. Press Fn, speak, release → correct transcript via Core ML
7. Switch back to Whisper → still works (cache reset)
