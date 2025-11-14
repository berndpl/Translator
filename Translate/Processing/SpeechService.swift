//
//  SpeechService.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import Foundation
import AVFoundation

// Use AVSpeechSynthesizer for modern, high-quality speech synthesis with enhanced voices
class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    private var synthesizer: AVSpeechSynthesizer?
    private var currentContinuation: CheckedContinuation<Void, Never>?
    private let queue = DispatchQueue(label: "SpeechService.queue", qos: .userInitiated)
    private var isSpeaking = false
    private var speechEnabled = true
    
    // Callbacks for speech events
    var onSpeechStart: ((String) -> Void)?
    var onSpeechEnd: (() -> Void)?
    
    // Voice selection - using AVSpeechSynthesisVoice identifiers
    private let voiceKey = "SelectedVoiceIdentifier"
    
    var selectedVoice: AVSpeechSynthesisVoice {
        get {
            if let voiceIdentifier = UserDefaults.standard.string(forKey: voiceKey),
               let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                return voice
            }
            // Default to enhanced English voice (prefer enhanced voices)
            return getDefaultEnhancedVoice()
        }
        set {
            UserDefaults.standard.set(newValue.identifier, forKey: voiceKey)
        }
    }
    
    var availableVoices: [AVSpeechSynthesisVoice] {
        // Get all available voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter duplicates by name (prefer enhanced versions)
        var uniqueVoices: [String: AVSpeechSynthesisVoice] = [:]
        
        for voice in allVoices {
            let key = voice.name.lowercased()
            
            // If we haven't seen this voice name, or if this is an enhanced version, use it
            if let existing = uniqueVoices[key] {
                // Prefer enhanced voices over non-enhanced
                if voice.quality == .enhanced && existing.quality != .enhanced {
                    uniqueVoices[key] = voice
                }
            } else {
                uniqueVoices[key] = voice
            }
        }
        
        // Convert back to array and sort: enhanced voices first, then by name
        return Array(uniqueVoices.values).sorted { voice1, voice2 in
            let enhanced1 = voice1.quality == .enhanced
            let enhanced2 = voice2.quality == .enhanced
            if enhanced1 != enhanced2 {
                return enhanced1 // Enhanced voices first
            }
            return voice1.name < voice2.name
        }
    }
    
    func getVoiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        var name = voice.name
        if voice.quality == .enhanced {
            name += " (Enhanced)"
        }
        return name
    }
    
    private func getDefaultEnhancedVoice() -> AVSpeechSynthesisVoice {
        // First, try to find Siri voices (prefer voice 2 if available)
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let siriVoices = allVoices.filter { voice in
            voice.name.localizedCaseInsensitiveContains("Siri")
        }
        
        // Sort Siri voices by name to get consistent ordering
        let sortedSiriVoices = siriVoices.sorted { $0.name < $1.name }
        
        // Prefer the second Siri voice (voice 2), fallback to first if only one exists
        if sortedSiriVoices.count >= 2 {
            print("🔊 [SpeechService] Found Siri voice 2: \(sortedSiriVoices[1].name)")
            return sortedSiriVoices[1]
        } else if let firstSiri = sortedSiriVoices.first {
            print("🔊 [SpeechService] Found Siri voice: \(firstSiri.name)")
            return firstSiri
        }
        
        // Fallback to Samantha voice
        if let samanthaVoice = allVoices.first(where: { voice in
            voice.name.localizedCaseInsensitiveContains("Samantha")
        }) {
            return samanthaVoice
        }
        
        // Try to find an enhanced English voice
        if let enhancedVoice = allVoices.first(where: { voice in
            voice.quality == .enhanced && voice.language.hasPrefix("en")
        }) {
            return enhancedVoice
        }
        
        // Fallback to any enhanced voice
        if let enhancedVoice = allVoices.first(where: { voice in
            voice.quality == .enhanced
        }) {
            return enhancedVoice
        }
        
        // Fallback to any English voice
        if let englishVoice = AVSpeechSynthesisVoice(language: "en-US") {
            return englishVoice
        }
        
        // Last resort: system default
        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice.speechVoices().first!
    }
    
    override init() {
        super.init()
        print("🔊 [SpeechService] INIT: Creating SpeechService instance")
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.delegate = self
        
        // Set Siri voice 2 as default if no voice has been saved yet
        if UserDefaults.standard.string(forKey: voiceKey) == nil {
            let defaultVoice = getDefaultEnhancedVoice()
            UserDefaults.standard.set(defaultVoice.identifier, forKey: voiceKey)
            print("🔊 [SpeechService] INIT: Set default voice to '\(defaultVoice.name)'")
        }
        
        print("🔊 [SpeechService] INIT: Synthesizer created and delegate set")
    }
    
    deinit {
        print("🔊 [SpeechService] DEINIT: SpeechService being deallocated")
        print("🔊 [SpeechService] DEINIT: State - isSpeaking: \(isSpeaking), synthesizer: \(synthesizer != nil ? "exists" : "nil"), continuation: \(currentContinuation != nil ? "exists" : "nil")")
        
        // Clean up synthesizer on main queue to avoid threading issues
        if let synth = synthesizer {
            DispatchQueue.main.async {
                synth.delegate = nil
                synth.stopSpeaking(at: .immediate)
            }
        }
        
        // Resume any pending continuation to prevent leaks
        if let continuation = currentContinuation {
            print("🔊 [SpeechService] DEINIT: Resuming pending continuation")
            continuation.resume()
        }
    }
    
    func speak(_ text: String) async {
        print("🔊 [SpeechService] speak() called with text: '\(text.prefix(50))...'")
        
        // Skip if speech is disabled
        guard speechEnabled else {
            print("⚠️ [SpeechService] Speech is disabled - returning immediately")
            // Simulate speech duration with a short delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            return
        }
        
        // Skip empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ [SpeechService] Empty text, skipping")
            return
        }
        
        print("🔊 [SpeechService] Waiting for current speech to finish...")
        // Wait for any current speech to finish
        await waitForCurrentSpeechToFinish()
        print("🔊 [SpeechService] Previous speech finished, starting new speech")
        
        return await withCheckedContinuation { continuation in
            print("🔊 [SpeechService] Creating continuation for new speech")
            queue.async { [weak self] in
                guard let self = self else {
                    print("❌ [SpeechService] Self is nil in queue.async")
                    continuation.resume()
                    return
                }
                
                print("🔊 [SpeechService] In queue, isSpeaking: \(self.isSpeaking)")
                
                // Ensure we're not already speaking
                guard !self.isSpeaking else {
                    print("⚠️ [SpeechService] Already speaking, skipping")
                    continuation.resume()
                    return
                }
                
                print("🔊 [SpeechService] Setting isSpeaking = true")
                self.isSpeaking = true
                self.currentContinuation = continuation
                print("🔊 [SpeechService] Stored continuation, currentContinuation is now: \(self.currentContinuation != nil ? "set" : "nil")")
                
                // Ensure synthesizer exists
                if self.synthesizer == nil {
                    print("🔊 [SpeechService] Creating new AVSpeechSynthesizer")
                    self.synthesizer = AVSpeechSynthesizer()
                    self.synthesizer?.delegate = self
                } else {
                    print("🔊 [SpeechService] Using existing synthesizer")
                }
                
                // Create utterance with selected voice
                print("🔊 [SpeechService] Creating AVSpeechUtterance")
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = self.selectedVoice
                utterance.rate = 0.5 // Default rate (0.0 to 1.0)
                utterance.pitchMultiplier = 1.0 // Default pitch
                utterance.volume = 1.0 // Full volume
                
                // Use enhanced quality if available
                if self.selectedVoice.quality == .enhanced {
                    utterance.rate = 0.52 // Slightly faster for enhanced voices
                }
                
                print("🔊 [SpeechService] Dispatching to main queue to start speaking")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        print("❌ [SpeechService] Self is nil on main queue")
                        return
                    }
                    
                    print("🔊 [SpeechService] On main queue, calling synthesizer.speak()")
                    print("🔊 [SpeechService] Synthesizer state - isSpeaking: \(self.isSpeaking), synthesizer: \(self.synthesizer != nil ? "exists" : "nil")")
                    
                    guard let synth = self.synthesizer else {
                        print("❌ [SpeechService] Synthesizer is nil on main queue")
                        // Resume continuation if synthesizer is nil
                        self.queue.async {
                            self.isSpeaking = false
                            if let continuation = self.currentContinuation {
                                self.currentContinuation = nil
                                continuation.resume()
                            }
                        }
                        return
                    }
                    
                    synth.speak(utterance)
                    print("✅ [SpeechService] Started speaking with voice '\(self.selectedVoice.name)' (Enhanced: \(self.selectedVoice.quality == .enhanced)): \(text.prefix(50))...")
                    
                    // Notify that speech has started
                    if let onStart = self.onSpeechStart {
                        onStart(text)
                    }
                }
            }
        }
    }
    
    private func waitForCurrentSpeechToFinish() async {
        print("🔊 [SpeechService] waitForCurrentSpeechToFinish() called")
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    print("❌ [SpeechService] Self is nil in waitForCurrentSpeechToFinish")
                    continuation.resume()
                    return
                }
                
                print("🔊 [SpeechService] In waitForCurrentSpeechToFinish queue, isSpeaking: \(self.isSpeaking)")
                
                guard self.isSpeaking else {
                    print("🔊 [SpeechService] Not speaking, resuming immediately")
                    continuation.resume()
                    return
                }
                
                print("🔊 [SpeechService] Currently speaking, stopping...")
                // Stop current speech if running
                DispatchQueue.main.async {
                    print("🔊 [SpeechService] On main queue, calling stopSpeaking")
                    self.synthesizer?.stopSpeaking(at: .immediate)
                    print("🔊 [SpeechService] stopSpeaking called")
                }
                
                self.isSpeaking = false
                print("🔊 [SpeechService] Set isSpeaking = false")
                
                // Wait a moment for cleanup
                print("🔊 [SpeechService] Waiting 0.3s for cleanup")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [continuation] in
                    print("🔊 [SpeechService] Cleanup delay complete, resuming continuation")
                    continuation.resume()
                }
            }
        }
        print("🔊 [SpeechService] waitForCurrentSpeechToFinish() completed")
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 [SpeechService] DELEGATE: didFinish called")
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [SpeechService] DELEGATE: Self is nil in didFinish")
                return
            }
            
            print("🔊 [SpeechService] DELEGATE: In didFinish queue handler")
            print("🔊 [SpeechService] DELEGATE: Current state - isSpeaking: \(self.isSpeaking), continuation: \(self.currentContinuation != nil ? "exists" : "nil")")
            
            self.isSpeaking = false
            print("🔊 [SpeechService] DELEGATE: Set isSpeaking = false")
            
            // Clear continuation reference before resuming to prevent any race conditions
            let continuation = self.currentContinuation
            self.currentContinuation = nil
            print("🔊 [SpeechService] DELEGATE: Cleared continuation reference")
            
            if let continuation = continuation {
                print("🔊 [SpeechService] DELEGATE: Resuming continuation after delay")
                // Add a delay to allow audio system to fully clean up before resuming
                // This prevents crashes related to AVAudioBuffer cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔊 [SpeechService] DELEGATE: Delay complete, resuming continuation")
                    continuation.resume()
                    print("🔊 [SpeechService] DELEGATE: Continuation resumed")
                }
            } else {
                print("⚠️ [SpeechService] DELEGATE: No continuation to resume")
            }
            
            // Notify that speech has ended
            if let onEnd = self.onSpeechEnd {
                DispatchQueue.main.async {
                    onEnd()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 [SpeechService] DELEGATE: didCancel called")
        queue.async { [weak self] in
            guard let self = self else {
                print("❌ [SpeechService] DELEGATE: Self is nil in didCancel")
                return
            }
            
            print("🔊 [SpeechService] DELEGATE: In didCancel queue handler")
            print("🔊 [SpeechService] DELEGATE: Current state - isSpeaking: \(self.isSpeaking), continuation: \(self.currentContinuation != nil ? "exists" : "nil")")
            
            self.isSpeaking = false
            print("🔊 [SpeechService] DELEGATE: Set isSpeaking = false")
            
            // Clear continuation reference before resuming
            let continuation = self.currentContinuation
            self.currentContinuation = nil
            print("🔊 [SpeechService] DELEGATE: Cleared continuation reference")
            
            if let continuation = continuation {
                print("🔊 [SpeechService] DELEGATE: Resuming continuation after cancel with delay")
                // Add delay for cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔊 [SpeechService] DELEGATE: Delay complete, resuming continuation after cancel")
                    continuation.resume()
                    print("🔊 [SpeechService] DELEGATE: Continuation resumed")
                }
            } else {
                print("⚠️ [SpeechService] DELEGATE: No continuation to resume after cancel")
            }
            
            // Notify that speech has ended
            if let onEnd = self.onSpeechEnd {
                DispatchQueue.main.async {
                    onEnd()
                }
            }
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("🔊 [SpeechService] DELEGATE: didContinue called")
        // Optional: handle continuation
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("🔊 [SpeechService] DELEGATE: didPause called")
        // Optional: handle pause
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Optional: track speaking progress
    }
}
