//
//  CaptionService.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 14.11.2025.
//

import AppKit
import SwiftUI

/// Standalone service for displaying captions in a floating window
/// Completely independent lifecycle - controlled by MarksManager but doesn't depend on it
/// Uses SwiftUI CaptionView for design flexibility
class CaptionService {
    // Singleton instance to maintain window lifecycle independently
    static let shared = CaptionService()
    
    private var captionWindow: NSWindow?
    private var hostingView: NSHostingView<CaptionView>?
    private var currentText: String = ""
    private var isInitialized = false
    
    private init() {
        // Private initializer for singleton
    }
    
    func showCaption(_ text: String) {
        print("📺 [CaptionService] showCaption called with text: '\(text.prefix(50))...'")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentText = text
            self.ensureWindowExists()
            self.updateCaption(text: text)
        }
    }
    
    func hideCaption() {
        print("📺 [CaptionService] hideCaption called")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hideWindow()
        }
    }
    
    private func ensureWindowExists() {
        // Create window only once and reuse it
        if captionWindow == nil {
            createWindow()
        }
    }
    
    private func createWindow() {
        print("📺 [CaptionService] Creating window (one-time initialization)")
        
        guard let screen = NSScreen.main else {
            print("❌ [CaptionService] No main screen found")
            return
        }
        
        let screenFrame = screen.frame
        let windowWidth: CGFloat = 800  // Wider for longer text
        let windowHeight: CGFloat = 200  // Taller to accommodate multiline text
        
        // Position at center bottom of screen
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.height * 0.1  // 10% from bottom
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // CRITICAL: Prevent window from being released when closed
        window.isReleasedWhenClosed = false
        
        window.level = .screenSaver
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        
        // Create SwiftUI hosting view with initial text
        let captionView = CaptionView(text: currentText)
        let hostingView = NSHostingView(rootView: captionView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        // Allow the hosting view to size itself based on content
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        window.contentView = hostingView
        
        // Store references
        captionWindow = window
        self.hostingView = hostingView
        
        isInitialized = true
        print("📺 [CaptionService] Window created with SwiftUI view and retained")
    }
    
    private func updateCaption(text: String) {
        guard let window = captionWindow, let hostingView = hostingView else {
            print("⚠️ [CaptionService] Window not initialized, creating now")
            ensureWindowExists()
            updateCaption(text: text)
            return
        }
        
        // Update the SwiftUI view by creating a new one with updated text
        // Show full text without truncation
        let updatedView = CaptionView(text: text)
        hostingView.rootView = updatedView
        
        // Invalidate intrinsic content size to allow the view to resize for long text
        hostingView.invalidateIntrinsicContentSize()
        
        // Show window using orderFront (doesn't deallocate)
        window.orderFront(nil)
        
        print("📺 [CaptionService] Caption updated and window shown (full text: \(text.count) characters)")
    }
    
    private func hideWindow() {
        guard let window = captionWindow else {
            print("📺 [CaptionService] No window to hide")
            return
        }
        
        // Clear text first to trigger fade-out animation
        if let hostingView = hostingView {
            hostingView.rootView = CaptionView(text: "")
        }
        
        // Wait for animation to complete before hiding window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Use orderOut instead of close - this hides without deallocating
            window.orderOut(nil)
            print("📺 [CaptionService] Window hidden (not closed, remains in memory)")
        }
    }
    
    // Cleanup method (call when app terminates)
    func cleanup() {
        print("📺 [CaptionService] Cleanup called")
        if let window = captionWindow {
            // Clear hosting view first
            hostingView?.rootView = CaptionView(text: "")
            hostingView = nil
            
            window.close()
            captionWindow = nil
        }
    }
}
