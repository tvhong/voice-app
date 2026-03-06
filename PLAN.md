# Plan: macOS Menu Bar Voice Transcription App

## Commit Checklist

- [x] Commit 1 — `feat: configure Info.plist`
- [x] Commit 2 — `feat: add AppDelegate with NSStatusItem and NSPopover`
- [ ] Commit 3 — `feat: implement AudioRecorder`
- [ ] Commit 4 — `feat: implement TranscriptionService`
- [ ] Commit 5 — `feat: implement RecorderView SwiftUI state machine`
- [ ] Commit 6 — `docs: add README with setup instructions`

## Architecture

```
NSStatusItem (AppDelegate)
    └── NSPopover
            └── RecorderView (SwiftUI)
                    ├── AudioRecorder (@Observable) — AVAudioEngine + AVAudioConverter
                    └── TranscriptionService       — SwiftWhisper + NSPasteboard
```

## Audio pipeline

```
Mic → AVAudioEngine.inputNode (native format: 48kHz/44.1kHz stereo)
    → installTap callback (per 4096 frames, audio thread)
    → AVAudioConverter → 16kHz mono Float32
    → [Float] accumulation
    → SwiftWhisper.transcribe()
    → NSPasteboard
```

## State machine (RecorderView)

```
idle ──startRecording()──> recording ──stop()──> transcribing ──done──> done(text)
done/error ──tap Start──> idle → recording
any ──error──> error(message)
```

## Notes

- SwiftWhisper already added via SPM (v1.2.0)
- Project uses GENERATE_INFOPLIST_FILE — switched to manual Info.plist in Commit 1
- Sandboxing disabled (app accesses real `~/Library/Application Support/`; not going to App Store)
- Entitlements file retains microphone access entitlement
- Model path: `~/Library/Application Support/VoiceApp/ggml-base.en.bin`
- Default actor isolation is MainActor (set in build settings) — audio thread appends must use explicit nonisolated context
