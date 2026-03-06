# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `VoiceApp/VoiceApp.xcodeproj` in Xcode and press **Cmd+R**. There is no CLI build system — all building, testing, and running is done through Xcode.

## Prerequisites

- Xcode 15+, macOS 13+
- Whisper model at `~/Library/Application Support/VoiceApp/ggml-base.en.bin` (see README for download command)

## Architecture

macOS menu bar app using SwiftUI + AppKit. Entry point is `VoiceAppApp.swift` which delegates to `AppDelegate`.

```
VoiceAppApp (@main)
└── AppDelegate (NSApplicationDelegateAdaptor)
    ├── NSStatusItem + NSPopover → RecorderView (SwiftUI)
    └── HotkeyManager — global Fn key monitor (requires Accessibility permission)

RecordingController (@Observable)  ← shared by AppDelegate + RecorderView
├── AudioRecorder — AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32
└── TranscriptionService — SwiftWhisper → NSPasteboard
```

**State machine** (`AppState` enum in `RecordingController`): `idle → recording → transcribing → done(text) | error(message)`

**Key files:**
- `RecordingController.swift` — central coordinator, owns `AppState`
- `AudioRecorder.swift` — audio capture and downsampling to Whisper's required format
- `TranscriptionService.swift` — loads model from `~/Library/Application Support/VoiceApp/` or bundle, runs Whisper, writes to clipboard
- `HotkeyManager.swift` — global + local `NSEvent` monitors for Fn key press/release
- `ModelConfig.swift` — single source of truth for model file path

**Dependency:** [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper) via Swift Package Manager (wraps whisper.cpp).

**Required permissions** (declared in `Info.plist`): Microphone (`NSMicrophoneUsageDescription`), Accessibility (`NSAccessibilityUsageDescription` — needed for the global Fn hotkey).
