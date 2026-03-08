# VoiceApp

A macOS menu bar app that records your microphone and transcribes speech to text using [Whisper](https://github.com/openai/whisper) via [WhisperKit](https://github.com/argmaxinc/WhisperKit). The transcription is automatically copied to your clipboard.

Built as a learning project to understand how apps like MacWhisper work under the hood.

## Prerequisites

- Xcode 15+
- macOS 13+

## Setup

### 1. Build and run

Open `VoiceApp/VoiceApp.xcodeproj` in Xcode and press **Cmd+R**.

## Usage

1. A mic icon appears in the menu bar (top-right of screen)
2. Click the icon to open the popover
3. Click **Start Recording** — grant microphone permission on first run
4. Speak, then click **Stop & Transcribe**
5. The transcription appears in the popover and is copied to your clipboard
6. Paste anywhere with **Cmd+V**

## Architecture

```
NSStatusItem (AppDelegate)
    └── NSPopover
            └── RecorderView (SwiftUI)
                    ├── AudioRecorder   — AVAudioEngine → 16kHz mono Float32 via AVAudioConverter
                    └── TranscriptionService — WhisperKit + NSPasteboard
```

## Settings

Open **VoiceApp → Settings** (Cmd+,) to choose the WhisperKit model; it will download automatically on first use.

## TODOs:

- [x] Make it faster
- [x] Improve the settings UI:
  - [x] List of items
  - [x] Allow deleting downloaded models to save disk space
  - [x] Download doesn't mean select
- [ ] Model verification
- [ ] Allow custom dictionary (and post processing?)
- [ ] Add an icon
- [ ] Updating the UI so that it's not a top bar anymore
