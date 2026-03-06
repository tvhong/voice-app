# VoiceApp

A macOS menu bar app that records your microphone and transcribes speech to text using [Whisper](https://github.com/openai/whisper) via [SwiftWhisper](https://github.com/exPHAT/SwiftWhisper). The transcription is automatically copied to your clipboard.

Built as a learning project to understand how apps like MacWhisper work under the hood.

## Prerequisites

- Xcode 15+
- macOS 13+

## Setup

### 1. Download the Whisper model

```bash
mkdir -p ~/Library/Application\ Support/VoiceApp
curl -L -o ~/Library/Application\ Support/VoiceApp/ggml-base.en.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
```

This downloads the `base.en` model (~148 MB, English-only). The app will show an error on transcription if the model is missing.

### 2. Build and run

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
                    └── TranscriptionService — SwiftWhisper + NSPasteboard
```

## Settings

Open **VoiceApp → Settings** (Cmd+,) to check whether the model file has been found.
