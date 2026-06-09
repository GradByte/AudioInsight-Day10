import Foundation
import AVFoundation
import Speech

/// `AudioEngineActor` is responsible for handling all audio session and speech recognition tasks.
/// By placing this logic in an Actor, we ensure that audio buffering, processing, and tap lifecycle
/// management happen off the main thread, preventing UI blocking or stuttering during heavy on-device
/// transcription workloads.
actor AudioEngineActor {
    
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer()
    
    /// Stream of transcribed text updates.
    private var textContinuation: AsyncStream<String>.Continuation?
    /// Stream of real-time audio power levels (RMS) for the visualizer.
    private var powerContinuation: AsyncStream<Float>.Continuation?
    
    /// A stream that yields transcribed text.
    let textStream: AsyncStream<String>
    /// A stream that yields RMS power levels.
    let powerStream: AsyncStream<Float>
    
    init() {
        // Initialize streams so the ViewModel can consume them.
        let (textStream, textContinuation) = AsyncStream<String>.makeStream()
        self.textStream = textStream
        self.textContinuation = textContinuation
        
        let (powerStream, powerContinuation) = AsyncStream<Float>.makeStream()
        self.powerStream = powerStream
        self.powerContinuation = powerContinuation
    }
    
    /// Starts the audio engine and the speech recognition request.
    func startRecording() async throws {
        // Cancel any previous task if it's running
        cancelRecording()
        
        // 1. Setup Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 2. Setup Recognition Request
        let request = SFSpeechAudioBufferRecognitionRequest()
        
        // PRIVACY FIRST: Ensure transcription only happens locally on the device.
        // This prevents any audio data from being sent to Apple's servers.
        // If on-device recognition is not available on this device/language, this request may fail,
        // which is expected as we strictly prioritize user privacy.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        // 3. Setup Audio Node & Tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            guard let self = self else { return }
            
            // Calculate Audio Power (RMS) for the UI Visualizer
            let channelData = buffer.floatChannelData?[0]
            let frameLength = UInt32(buffer.frameLength)
            
            var rms: Float = 0.0
            if let channelData = channelData {
                for i in 0..<Int(frameLength) {
                    let sample = channelData[i]
                    rms += sample * sample
                }
                rms = sqrt(rms / Float(frameLength))
            }
            
            // We use a Task to enter the actor isolation context and yield values
            Task {
                await self.appendBufferAndYieldPower(buffer: buffer, power: rms)
            }
        }
        
        // 4. Start Audio Engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // 5. Start Recognition Task
        // We use the optional unwrap to ensure the request is valid.
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { [weak self] (result, error) in
            // Handle results. Since resultHandler is called on a background queue,
            // we dispatch updates back to the actor.
            Task {
                await self?.handleRecognitionResult(result: result, error: error)
            }
        })
    }
    
    /// Helper method to safely append buffers and yield power within the actor's context.
    private func appendBufferAndYieldPower(buffer: AVAudioPCMBuffer, power: Float) {
        // Append buffer to our ongoing request
        self.recognitionRequest?.append(buffer)
        
        // Yield the current RMS power back to the visualizer stream
        self.powerContinuation?.yield(power)
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let text = result.bestTranscription.formattedString
            if !text.isEmpty {
                self.textContinuation?.yield(text)
            }
        }
        
        // If there's an error or the result is strictly final, we can stop recording.
        if error != nil || result?.isFinal == true {
            self.stopRecording()
        }
    }
    
    /// Safely stops the recording and tears down the audio pipeline without leaking memory.
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Signal that no more audio will be appended.
        // This allows the recognition task to finish cleanly.
        recognitionRequest?.endAudio()
        
        // Invalidate the audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // To break retain cycles and prevent memory leaks over long or repeated sessions,
        // we explicitly nil out the request and let the task finish naturally.
        recognitionRequest = nil
        
        // We don't forcefully cancel the task here if we want the final results,
        // but since we are stopping, we might wait for the `isFinal` flag.
        // For absolute safety of teardown, if we just want to stop, we can leave the task
        // to finish parsing the remaining buffer. Once it hits final, `handleRecognitionResult`
        // will naturally complete. We nil our local reference so it can be deallocated.
        recognitionTask = nil
    }
    
    /// Forcefully cancels the recording and discards pending results.
    private func cancelRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
    
    deinit {
        // Make sure streams are terminated if the actor is deallocated.
        textContinuation?.finish()
        powerContinuation?.finish()
    }
}
