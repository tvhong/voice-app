# VoiceApp

A macOS menu bar app that records your microphone and transcribes speech to text using [Whisper](https://github.com/openai/whisper) via [WhisperKit](https://github.com/argmaxinc/WhisperKit). The transcription is automatically copied to your clipboard and pasted at the cursor.

Built as a learning project to understand how apps like MacWhisper work under the hood.

## Prerequisites

- Xcode 15+
- macOS 13+

## Setup

Open `VoiceApp/VoiceApp.xcodeproj` in Xcode and press **Cmd+R**.

## Usage

1. A mic icon appears in the menu bar (top-right of screen)
2. Press and hold **Fn** (globe key) to start recording — or click the menu bar icon to open the popover and use the button there
3. A floating mic circle appears on screen while recording
4. Release **Fn** (or click **Stop & Transcribe**) to transcribe
5. The transcription is copied to your clipboard and auto-pasted at the cursor
6. View past transcriptions in the **History** tab of the main window

Grant microphone and accessibility permissions on first run.

## Architecture

```
VoiceAppApp (@main)
├── AppDelegate
│   ├── NSStatusItem + NSPopover → RecorderView (SwiftUI popover)
│   ├── FloatingMicView          — overlay circle shown during recording
│   └── HotkeyManager            — global Fn key monitor (requires Accessibility)
└── Window scene → TabView
    ├── HistoryView   — shows past transcriptions
    └── SettingsView  — model selection, download, delete

RecordingController (@Observable)  ← shared by AppDelegate + RecorderView
├── AudioRecorder        — AVAudioEngine tap → AVAudioConverter → 16kHz mono Float32
├── TranscriptionService — WhisperKit → NSPasteboard + CGEvent auto-paste
└── TranscriptionHistory — in-memory list of transcription records
```

**State machine** (`AppState`): `idle → recording → transcribing → done(text) | error(message)`

## Settings

Open **VoiceApp → Settings** (Cmd+,) to choose the WhisperKit model; it downloads automatically on first use. Models are cached at `~/Library/Application Support/VoiceApp/WhisperKitModels/` and can be deleted from the Settings UI to free disk space.

## TODOs:

- [ ] Allow custom dictionary (and post-processing)
- [ ] Support customising keyboard shortcuts
