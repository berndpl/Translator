//
//  VoicePickerView.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    private let speechService = SpeechService()
    @State private var selectedVoiceIdentifier: String
    
    init() {
        let service = SpeechService()
        _selectedVoiceIdentifier = State(initialValue: service.selectedVoice.identifier)
    }
    
    var body: some View {
        Picker("", selection: $selectedVoiceIdentifier) {
            ForEach(speechService.availableVoices, id: \.identifier) { (voice: AVSpeechSynthesisVoice) in
                Text(speechService.getVoiceDisplayName(voice))
                    .tag(voice.identifier)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedVoiceIdentifier) { oldValue, newValue in
            if let voice = AVSpeechSynthesisVoice(identifier: newValue) {
                speechService.selectedVoice = voice
                print("🔊 [VoicePickerView] Selected voice: \(voice.name) (identifier: \(newValue))")
            } else {
                print("⚠️ [VoicePickerView] Could not find voice with identifier: \(newValue)")
            }
        }
        .onAppear {
            // Sync with current selection
            selectedVoiceIdentifier = speechService.selectedVoice.identifier
        }
    }
}

