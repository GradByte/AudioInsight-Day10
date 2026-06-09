import Foundation
import Observation
import Speech

/// `TranscriptionViewModel` binds the UI to the underlying audio actor using modern Observation.
/// It operates on the `MainActor` to ensure that all UI updates are properly dispatched to the main thread.
@MainActor
@Observable
class TranscriptionViewModel {
    
    // UI State
    var isRecording: Bool = false
    var transcribedText: String = ""
    var currentAudioPower: Float = 0.0
    var errorMessage: String?
    
    // Dependencies
    private var audioEngineActor: AudioEngineActor?
    
    // Tasks for streaming data back to the ViewModel
    private var textStreamTask: Task<Void, Never>?
    private var powerStreamTask: Task<Void, Never>?
    
    init() {
        // Initialization can be minimal. We will instantiate the actor when recording starts or during init.
        setupActor()
    }
    
    private func setupActor() {
        let actor = AudioEngineActor()
        self.audioEngineActor = actor
        
        // Start consuming streams from the actor
        textStreamTask?.cancel()
        textStreamTask = Task { [weak self] in
            for await text in actor.textStream {
                self?.transcribedText = text
            }
        }
        
        powerStreamTask?.cancel()
        powerStreamTask = Task { [weak self] in
            for await power in actor.powerStream {
                // To make the visualizer snappy, we just update the float.
                // We map raw RMS (typically 0.0 to 1.0, though can vary) to a safe range.
                let normalizedPower = max(0.0, min(1.0, power * 10.0)) // simple scaling
                self?.currentAudioPower = normalizedPower
            }
        }
    }
    
    /// Requests microphone and speech permissions from the user.
    func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechAuthorized else { return false }
        
        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        return micAuthorized
    }
    
    /// Toggles the recording state.
    func toggleRecording() {
        Task {
            if isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }
    
    private func startRecording() async {
        let authorized = await requestPermissions()
        guard authorized else {
            self.errorMessage = "Please enable Microphone and Speech Recognition in Settings."
            return
        }
        
        // Re-setup the actor to get fresh streams if needed, or clear text
        self.transcribedText = ""
        self.errorMessage = nil
        self.currentAudioPower = 0.0
        
        do {
            try await audioEngineActor?.startRecording()
            self.isRecording = true
        } catch {
            self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func stopRecording() async {
        await audioEngineActor?.stopRecording()
        self.isRecording = false
        self.currentAudioPower = 0.0
    }
    

}
