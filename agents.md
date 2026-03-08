# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `VoiceApp/VoiceApp.xcodeproj` in Xcode and press **Cmd+R** to run.

To verify a build from the CLI:
```
cd VoiceApp && xcodebuild -project VoiceApp.xcodeproj -scheme VoiceApp -configuration Debug build
```

## Prerequisites

- Xcode 15+, macOS 13+
- WhisperKit models are downloaded automatically on first use via the Settings tab. No manual model setup required.

## Architecture

macOS app with two surfaces: a menu bar popover and a standard window (History + Settings tabs). Both share a single `RecordingController` owned by `AppDelegate`.

```
VoiceAppApp (@main)
├── AppDelegate (NSApplicationDelegateAdaptor)
│   ├── NSStatusItem + NSPopover → RecorderView (SwiftUI popover)
│   ├── FloatingMicView (overlay circle shown during recording)
│   └── HotkeyManager — global Fn key monitor (requires Accessibility permission)
└── Window scene → TabView
    ├── HistoryView — shows TranscriptionHistory.records
    └── SettingsView — model selection, download, delete

RecordingController (@Observable)  ← shared by AppDelegate + RecorderView
├── AudioRecorder — AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32
├── TranscriptionService — WhisperKit → NSPasteboard (auto-pastes via CGEvent Cmd+V)
└── TranscriptionHistory — in-memory list of TranscriptionRecord (not persisted)
```

**State machine** (`AppState` enum in `RecordingController`): `idle → recording → transcribing → done(text) | error(message)`

**Key files:**
- `RecordingController.swift` — central coordinator, owns `AppState` and `TranscriptionHistory`
- `AudioRecorder.swift` — audio capture and downsampling to Whisper's required format
- `TranscriptionService.swift` — lazy-loads WhisperKit (reloads if model changes), trims silence, writes to clipboard
- `HotkeyManager.swift` — global + local `NSEvent` monitors for Fn key press/release
- `ModelConfig.swift` — single source of truth for model selection (`UserDefaults`)
- `WhisperKitModelStore.swift` — model prep check, download, verify, delete; cache at `~/Library/Application Support/VoiceApp/WhisperKitModels/`
- `ModelIntegrityVerifier.swift` — SHA-256 verification against embedded manifest hashes
- `VerificationMarkerStore.swift` — persists verification results to skip re-hashing on subsequent launches
- `ModelFilesystem.swift` — filesystem helpers for locating WhisperKit model folders

**Dependency:** [WhisperKit](https://github.com/argmaxinc/WhisperKit) via Swift Package Manager (Apple MLCompute/CoreML-based Whisper inference).

**Required permissions** (declared in `Info.plist`): Microphone (`NSMicrophoneUsageDescription`), Accessibility (`NSAccessibilityUsageDescription` — needed for the global Fn hotkey and `CGEvent` paste simulation).
