//
//  ContentView.swift
//  AudioInsight
//
//  Created by Efe Ertekin on 9.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TranscriptionViewModel()
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // Visualizer
                VisualizerView(power: viewModel.currentAudioPower)
                    .frame(height: 100)
                    .padding()
                    .animation(.easeInOut(duration: 0.1), value: viewModel.currentAudioPower)
                
                // Transcription Box
                TextEditor(text: $viewModel.transcribedText)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .focused($isTextEditorFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isTextEditorFocused = false
                            }
                        }
                    }
                    // The view model manages the text directly, but SwiftUI TextEditor requires a binding.
                    // We bind directly to the @Observable property.
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Record Button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                        
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("AudioInsight")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// A simple visualizer that scales a few bars based on the current audio power level.
struct VisualizerView: View {
    var power: Float
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .frame(width: 20, height: max(10, CGFloat(power) * 100 * (CGFloat(index % 3) + 0.5))) // pseudo-random height factor
            }
        }
    }
}

#Preview {
    ContentView()
}
