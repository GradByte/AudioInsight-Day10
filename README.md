# AudioInsight

AudioInsight is a professional-grade, privacy-focused iOS utility app built entirely with SwiftUI. Its core purpose is to transcribe voice memos and live audio into text entirely on-device, ensuring complete privacy with zero network dependencies.

## Features

- **On-Device Transcription**: Utilizes Apple's `SFSpeechRecognizer` forced into local-only mode, guaranteeing that no audio data ever leaves your device.
- **Modern Concurrency**: Powered by Swift 6 Actors and `@Observable` view models for strict main-thread isolation and stutter-free UI updates.
- **Real-Time Visualizer**: Dynamic audio visualizer driven directly by `AVAudioPCMBuffer` RMS calculations during the recording session.
- **Robust Memory Management**: Background audio tasks gracefully handle initialization and teardown via precise `SFSpeechAudioBufferRecognitionRequest` lifecycle control to prevent memory leaks across long sessions.

## Requirements

- **iOS 17.0+** (or the latest iOS 26+ equivalent standard)
- **Xcode 15.0+**
- Swift 5.9+

## Installation

1. Clone or download this repository.
2. Open `AudioInsight.xcodeproj` in Xcode.
3. Select your target Simulator or physical device.
4. Build and Run (`Cmd + R`).

## Privacy & Permissions

AudioInsight requires the following permissions to function:
- **Microphone**: Needed to capture live audio.
- **Speech Recognition**: Needed to perform the actual transcription. 

Because the transcription engine is strictly configured with `requiresOnDeviceRecognition = true`, all processing happens entirely offline.

## Architecture

The app uses a modern **MVVM** pattern:
- **`AudioEngineActor`**: An isolated `actor` that handles the `AVAudioEngine` pipeline and safely manages speech recognition streams off the main UI thread.
- **`TranscriptionViewModel`**: An `@Observable` Swift class that bridges the asynchronous data streams from the audio actor directly into the UI state.
- **`ContentView`**: A clean, minimal SwiftUI interface providing the core visualizer and interactive components.

## License

This project is open-source and available under the MIT License.
