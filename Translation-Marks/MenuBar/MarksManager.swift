//
//  MarksManager.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI
import Combine
import AppKit
import NaturalLanguage

/// Consolidated manager that coordinates capture and processing
/// Allows toggling individual processors and sequence parts for debugging
struct CaptureResult {
    let originalImage: NSImage
    let annotatedImage: NSImage
    let textRegions: [TextRegion]
    let allText: String
}

class MarksManager: ObservableObject {
    // MARK: - Capture Components
    private let selection = ScreenCaptureSelection()
    private let textDetector = ScreenCaptureTextDetector()
    private let overlay = ScreenCaptureOverlay()
    private let storage = ScreenCaptureStorage()
    
    // MARK: - Processing Components
    private let translationService = TranslationService()
    private let speechService = SpeechService()
    // Use shared singleton instance - independent lifecycle
    private let captionService = CaptionService.shared
    
    // MARK: - Keyboard Shortcut
    private let keyboardShortcut = MenuBarKeyboardShortcut()
    
    // MARK: - Published State
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    
    // Store the last selected region position for caption positioning
    private var lastSelectedRegion: CGRect?
    
    // MARK: - Feature Toggles (for debugging/isolating issues)
    @Published var enableCapture = true
    @Published var enableTextDetection = true
    @Published var enableOverlayDrawing = true
    @Published var enableScreenshotSaving = true
    @Published var enableTranslation = true
    @Published var enableTranslationSpeech = true
    @Published var enableCaptions = true {
        didSet {
            // If captions are disabled, hide the caption window
            if !enableCaptions {
                captionService.hideCaption()
            }
        }
    }
    
    init() {
        setupKeyboardShortcut()
        setupSpeechCallbacks()
        setupCaptionService()
    }
    
    private func setupCaptionService() {
        // CaptionService is now a standalone singleton
        // No setup needed - it manages its own lifecycle
        print("📺 [MarksManager] CaptionService singleton ready")
    }
    
    private func setupSpeechCallbacks() {
        speechService.onSpeechStart = { [weak self] text in
            guard let self = self else { return }
            print("📺 [MarksManager] onSpeechStart callback called, text: '\(text.prefix(50))...', enableCaptions: \(self.enableCaptions)")
            // Check enableCaptions on main thread since it's a @Published property
            Task { @MainActor in
                if self.enableCaptions {
                    print("📺 [MarksManager] Showing caption above selected region")
                    // Position caption above the selected region if available
                    if let region = self.lastSelectedRegion {
                        self.captionService.showCaption(text, aboveRegion: region)
                    } else {
                        // Fallback to default position
                        self.captionService.showCaption(text)
                    }
                } else {
                    print("📺 [MarksManager] Captions disabled, not showing")
                }
            }
        }
        
        speechService.onSpeechEnd = { [weak self] in
            guard let self = self else { return }
            print("📺 [MarksManager] onSpeechEnd callback called, enableCaptions: \(self.enableCaptions)")
            Task { @MainActor in
                if self.enableCaptions {
                    // Hide caption after a delay to allow reading
                    // The caption service manages its own lifecycle independently
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("📺 [MarksManager] Hiding caption")
                        self.captionService.hideCaption()
                    }
                }
            }
        }
    }
    
    private func setupKeyboardShortcut() {
        keyboardShortcut.onShortcutPressed = { [weak self] in
            Task { @MainActor in
                await self?.handleCaptureAndProcess()
            }
        }
    }
    
    // MARK: - Main Workflow
    
    func handleCaptureAndProcess() async {
        print("🎯 [MarksManager] Starting capture and process workflow")
        
        // Check if already processing
        if await MainActor.run(body: { isProcessing }) {
            print("⚠️ [MarksManager] Already processing, ignoring duplicate request")
            return
        }
        
        await MainActor.run {
            isProcessing = true
            statusMessage = "Select area to capture..."
        }
        
        // Ensure we always reset isProcessing
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Step 1: Capture
        guard enableCapture else {
            print("⚠️ [MarksManager] Capture disabled, skipping")
            await MainActor.run {
                statusMessage = "Capture disabled"
            }
            return
        }
        
        guard let captureResult = await performCapture() else {
            await MainActor.run {
                statusMessage = "Capture cancelled"
            }
            return
        }
        
        let annotatedImage = captureResult.annotatedImage
        let textRegions = captureResult.textRegions
        
        if textRegions.isEmpty {
            print("⚠️ [MarksManager] No text regions found")
            await MainActor.run {
                statusMessage = "No text found"
            }
            return
        }
        
        print("✅ [MarksManager] Found \(textRegions.count) text regions")
        
        // Step 2: Translate and read translation
        if enableTranslation || enableTranslationSpeech {
            await MainActor.run {
                statusMessage = "Translating from Japanese to English..."
            }
            
            if enableTranslation {
                let translationPairs = await translationService.translateRegions(textRegions, from: .japanese)
                let translatedText = translationPairs.map { $0.translated }.joined(separator: " ")
                
                if enableTranslationSpeech && !translatedText.isEmpty {
                    await MainActor.run {
                        statusMessage = "Reading translation..."
                    }
                    await speechService.speak(translatedText)
                    
                    // Wait for audio cleanup
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
            } else {
                print("⚠️ [MarksManager] Translation disabled, skipping")
            }
        }
        
        await MainActor.run {
            statusMessage = "Complete"
            
            // Reset status after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.statusMessage = "Ready"
            }
        }
    }
    
    // MARK: - Capture Process
    
    private func performCapture() async -> CaptureResult? {
        print("📸 [MarksManager] Starting capture process")
        
        // Check screen recording permission first
        let hasPermission = await MenuBarPermissions.checkScreenRecordingPermission()
        if !hasPermission {
            print("❌ [MarksManager] Screen recording permission not granted")
            await MainActor.run {
                statusMessage = "Permission required"
            }
            MenuBarPermissions.showPermissionAlert()
            return nil
        }
        
        // Step 1: Capture selected area
        guard let captureResult = await selection.captureSelectedArea() else {
            print("❌ [MarksManager] Screen capture cancelled or failed")
            return nil
        }
        
        let image = captureResult.image
        lastSelectedRegion = captureResult.screenRect
        
        print("✅ [MarksManager] Screenshot captured, size: \(image.size), region: \(captureResult.screenRect)")
        
        // Step 2: Detect text regions
        var textRegions: [TextRegion] = []
        var allText = ""
        
        if enableTextDetection {
            print("🔍 [MarksManager] Detecting text regions...")
            textRegions = await textDetector.extractTextRegions(from: image)
            allText = textRegions.map { $0.text }.joined(separator: " ")
            print("📝 [MarksManager] Found \(textRegions.count) text region(s)")
        } else {
            print("⚠️ [MarksManager] Text detection disabled, skipping")
        }
        
        // Step 3: Draw overlay rectangles on image
        // Only draw if overlay drawing is enabled (this affects the saved image)
        var annotatedImage = image
        if enableOverlayDrawing && !textRegions.isEmpty {
            print("🎨 [MarksManager] Drawing overlay rectangles on image...")
            annotatedImage = overlay.drawTextRegionsOnImage(image: image, regions: textRegions)
            print("✅ [MarksManager] Overlay rectangles drawn on image")
        } else {
            print("⚠️ [MarksManager] Overlay drawing disabled or no text regions - saving original image without overlays")
        }
        
        // Step 4: Save screenshot
        if enableScreenshotSaving {
            print("💾 [MarksManager] Saving screenshot...")
            storage.saveScreenshot(annotatedImage)
            print("✅ [MarksManager] Screenshot saved")
        } else {
            print("⚠️ [MarksManager] Screenshot saving disabled, skipping")
        }
        
        return CaptureResult(
            originalImage: image,
            annotatedImage: annotatedImage,
            textRegions: textRegions,
            allText: allText
        )
    }
}

