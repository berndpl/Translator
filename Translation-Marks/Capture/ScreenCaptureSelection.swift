//
//  ScreenCaptureSelection.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit
import SwiftUI
import ScreenCaptureKit
import CoreMedia
import CoreImage

struct SelectionResult {
    let image: NSImage
    let screenRect: CGRect // Screen coordinates of the selected region
}

class ScreenCaptureSelection {
    private var selectionWindow: NSWindow?
    private var continuation: CheckedContinuation<SelectionResult?, Never>?
    private var eventMonitor: Any?
    private let queue = DispatchQueue(label: "ScreenCaptureSelection.queue")
    
    func captureSelectedArea() async -> SelectionResult? {
        // Clean up any existing state first
        await cleanup()
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                // Clear any existing continuation
                self.continuation = nil
                self.continuation = continuation
                self.showSelectionOverlay()
            }
        }
    }
    
    private func cleanup() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Remove event monitor
                if let monitor = self.eventMonitor {
                    DispatchQueue.main.async {
                        NSEvent.removeMonitor(monitor)
                    }
                    self.eventMonitor = nil
                }
                
                // Close any existing window
                if let window = self.selectionWindow {
                    DispatchQueue.main.async {
                        window.close()
                    }
                    self.selectionWindow = nil
                }
                
                // Clear any existing continuation (shouldn't happen, but safety check)
                if let oldContinuation = self.continuation {
                    oldContinuation.resume(returning: nil)
                    self.continuation = nil
                }
                
                // Small delay to ensure cleanup completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [continuation] in
                    continuation.resume()
                }
            }
        }
    }
    
    private func showSelectionOverlay() {
        DispatchQueue.main.async {
            // Create a full-screen transparent window for selection
            let screenFrame = NSScreen.main?.frame ?? .zero
            let window = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
            window.isOpaque = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let overlayView = SelectionOverlayView(
                onSelectionComplete: { [weak self] rect in
                    self?.handleSelection(rect: rect, window: window)
                },
                onCancel: { [weak self] in
                    self?.handleCancel(window: window)
                }
            )
            
            let hostingView = NSHostingView(rootView: overlayView)
            window.contentView = hostingView
            
            // Make window accept keyboard events - CRITICAL for ESC to work
            window.acceptsMouseMovedEvents = true
            window.makeKeyAndOrderFront(nil)
            
            // Force window to become key window and accept keyboard events
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            
            // Make the hosting view the first responder to receive keyboard events
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeFirstResponder(hostingView)
            }
            
            // Set up event monitor to catch ESC key - use global monitor for reliability
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self = self else { return event }
                
                // Check for ESC key (keyCode 53)
                if event.keyCode == 53 {
                    print("📺 [ScreenCaptureSelection] ESC key detected, canceling selection")
                    self.handleCancel(window: window)
                    return nil // Consume the event
                }
                
                return event
            }
            
            self.selectionWindow = window
            
            print("📺 [ScreenCaptureSelection] Selection overlay shown, ESC key monitoring active")
        }
    }
    
    private func handleCancel(window: NSWindow) {
        print("📺 [ScreenCaptureSelection] handleCancel called")
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Remove event monitor first
                if let monitor = self.eventMonitor {
                    print("📺 [ScreenCaptureSelection] Removing event monitor")
                    NSEvent.removeMonitor(monitor)
                    self.eventMonitor = nil
                }
                
                window.close()
            }
            
            self.selectionWindow = nil
            if let cont = self.continuation {
                self.continuation = nil
                cont.resume(returning: nil)
            }
        }
    }
    
    private func handleSelection(rect: CGRect, window: NSWindow) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Read AppKit properties on main thread
            var capturedWindowFrame: CGRect = .zero
            var capturedScreen: NSScreen?
            DispatchQueue.main.sync {
                // Remove event monitor
                if let monitor = self.eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.eventMonitor = nil
                }
                
                capturedWindowFrame = window.frame
                capturedScreen = NSScreen.main
                window.close()
            }

            self.selectionWindow = nil

            // Use captured values off the main thread
            guard let screen = capturedScreen else {
                if let cont = self.continuation {
                    self.continuation = nil
                    cont.resume(returning: nil)
                }
                return
            }

            let screenRect = screen.frame
            let windowFrame = capturedWindowFrame

            // Convert from view coordinates (top-left origin) to screen coordinates (bottom-left origin)
            let captureRect = CGRect(
                x: windowFrame.origin.x + rect.origin.x,
                y: screenRect.height - (windowFrame.origin.y + rect.origin.y + rect.height),
                width: rect.width,
                height: rect.height
            )

            print("Debug: Selection rect (view): \(rect)")
            print("Debug: Window frame: \(windowFrame)")
            print("Debug: Screen frame: \(screenRect)")
            print("Debug: Capture rect (screen): \(captureRect)")

            // Use ScreenCaptureKit for modern screen capture
            guard let cont = self.continuation else { return }
            self.continuation = nil // Clear immediately to prevent double resume

            Task {
                if let image = await self.captureScreenArea(rect: captureRect, screen: screen) {
                    let result = SelectionResult(image: image, screenRect: captureRect)
                    cont.resume(returning: result)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
    
    private func captureScreenArea(rect: CGRect, screen: NSScreen) async -> NSImage? {
        do {
            // Get available content - this will fail with TCC error if permission not granted
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Find the display that matches our screen
            let display = availableContent.displays.first { display in
                display.frame.intersects(screen.frame)
            } ?? availableContent.displays.first
            
            guard let display = display else {
                print("No display found")
                return nil
            }
            
            print("Debug: Display frame: \(display.frame)")
            
            // Convert screen coordinates to display-relative coordinates
            let displayFrame = display.frame
            let displayRelativeRect = CGRect(
                x: rect.origin.x - displayFrame.origin.x,
                y: (displayFrame.height - (rect.origin.y - displayFrame.origin.y) - rect.height),
                width: rect.width,
                height: rect.height
            )
            
            print("Debug: Display-relative rect: \(displayRelativeRect)")
            
            // Create filter for the display
            let filter = SCContentFilter(display: display, excludingWindows: [])
            
            // Create stream configuration - use sourceRect to capture only the selected area
            let streamConfig = SCStreamConfiguration()
            streamConfig.width = Int(rect.width * 2) // Retina resolution
            streamConfig.height = Int(rect.height * 2)
            streamConfig.sourceRect = displayRelativeRect
            streamConfig.showsCursor = false
            streamConfig.queueDepth = 1
            
            return await withCheckedContinuation { continuation in
                // Create output handler class with thread-safe state using actor
                actor CaptureState {
                    var hasResumed = false
                    
                    func checkAndSetResumed() -> Bool {
                        if hasResumed {
                            return false
                        }
                        hasResumed = true
                        return true
                    }
                }
                
                let state = CaptureState()
                
                // Create output handler class
                class CaptureOutput: NSObject, SCStreamOutput {
                    var continuation: CheckedContinuation<NSImage?, Never>?
                    let state: CaptureState
                    let captureRect: CGRect
                    var stream: SCStream?
                    private var hasStopped = false
                    private let stopLock = NSLock()
                    
                    init(continuation: CheckedContinuation<NSImage?, Never>, 
                         state: CaptureState,
                         captureRect: CGRect) {
                        self.continuation = continuation
                        self.state = state
                        self.captureRect = captureRect
                    }
                    
                    func safeStopStream(_ stream: SCStream) {
                        stopLock.lock()
                        defer { stopLock.unlock() }
                        
                        guard !hasStopped else { return }
                        hasStopped = true
                        
                        Task {
                            do {
                                try await stream.stopCapture()
                            } catch {
                                // Check if it's the expected "already stopped" error (code -3808)
                                // The error domain is com.apple.ScreenCaptureKit.SCStreamErrorDomain
                                let nsError = error as NSError
                                if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3808 {
                                    // This is expected - stream was already stopped, silently ignore
                                    return
                                }
                                // Only log unexpected errors
                                print("⚠️ Unexpected stream stop error: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
                        guard type == .screen else { return }
                        
                        Task {
                            let shouldProcess = await state.checkAndSetResumed()
                            guard shouldProcess else { return }
                            
                            guard let imageBuffer = sampleBuffer.imageBuffer else {
                                continuation?.resume(returning: nil)
                                safeStopStream(stream)
                                return
                            }
                            
                            let ciImage = CIImage(cvImageBuffer: imageBuffer)
                            let context = CIContext()
                            
                            let expectedSize = CGSize(width: captureRect.width * 2, height: captureRect.height * 2)
                            
                            var finalImage = ciImage
                            if ciImage.extent.size != expectedSize {
                                let cropRect = CGRect(x: 0, y: 0, width: expectedSize.width, height: expectedSize.height)
                                finalImage = ciImage.cropped(to: cropRect)
                            }
                            
                            guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else {
                                continuation?.resume(returning: nil)
                                safeStopStream(stream)
                                return
                            }
                            
                            let image = NSImage(cgImage: cgImage, size: captureRect.size)
                            continuation?.resume(returning: image)
                            
                            // Stop the stream
                            safeStopStream(stream)
                        }
                    }
                }
                
                let output = CaptureOutput(
                    continuation: continuation,
                    state: state,
                    captureRect: rect
                )
                
                // Create and start stream
                let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
                output.stream = stream
                
                Task {
                    do {
                        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
                        try await stream.startCapture()
                        
                        // Wait for a frame (max 1 second)
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        
                        // If we haven't received an image yet, stop and return nil
                        let shouldResume = await state.checkAndSetResumed()
                        if shouldResume {
                            continuation.resume(returning: nil)
                            // Stop the stream safely
                            output.safeStopStream(stream)
                        }
                    } catch {
                        print("⚠️ Screen capture error: \(error)")
                        let shouldResume = await state.checkAndSetResumed()
                        if shouldResume {
                            continuation.resume(returning: nil)
                        }
                        
                        // Stop the stream safely on error
                        output.safeStopStream(stream)
                    }
                }
            }
        } catch {
            // Check if it's a TCC permission error
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3801 {
                print("❌ Screen capture error: Permission denied (TCC). User needs to grant screen recording permission in System Settings.")
            } else {
                print("❌ Screen capture error: \(error)")
            }
            return nil
        }
    }
}

// Selection overlay view (moved from ScreenCaptureManager)
struct SelectionOverlayView: View {
    let onSelectionComplete: (CGRect) -> Void
    let onCancel: (() -> Void)?
    
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    
    init(onSelectionComplete: @escaping (CGRect) -> Void, onCancel: (() -> Void)? = nil) {
        self.onSelectionComplete = onSelectionComplete
        self.onCancel = onCancel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                
                // Selection rectangle
                if let start = startPoint, let current = currentPoint {
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: abs(current.x - start.x),
                        height: abs(current.y - start.y)
                    )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
                
                // Instructions
                VStack(spacing: 8) {
                    // App icon - use high resolution source image
                    if let iconImage = loadHighResIcon() {
                        Image(nsImage: iconImage)
                            .renderingMode(.template)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: 120, height: 120)
                    } else {
                        // Fallback to asset catalog
                        Image("MenuBarIcon")
                            .renderingMode(.template)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: 120, height: 120)
                    }
                    
                    Text("Select area to translate")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    Text("Press ESC to cancel")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.location
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        if let start = startPoint, let end = currentPoint {
                            let rect = CGRect(
                                x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y)
                            )
                            
                            if rect.width > 10 && rect.height > 10 {
                                onSelectionComplete(rect)
                            } else {
                                onCancel?()
                            }
                        }
                        startPoint = nil
                        currentPoint = nil
                    }
            )
            .onKeyPress(.escape) {
                onCancel?()
                return .handled
            }
        }
    }
    
    /// Loads the high-resolution icon (1024x1024) for crisp display
    private func loadHighResIcon() -> NSImage? {
        // Try loading from bundle resources first (if added to project)
        if let image = NSImage(named: "MenuBarIcon_source") {
            return image
        }
        
        // Try loading from the Icons folder in the project
        // This works during development, but for production we should add to asset catalog
        guard let bundle = Bundle.main.resourceURL else { return nil }
        
        // Try source image (1024x1024)
        let sourceURL = bundle.appendingPathComponent("../Icons/MenuBarIcon_source.png")
        if FileManager.default.fileExists(atPath: sourceURL.path),
           let image = NSImage(contentsOf: sourceURL) {
            return image
        }
        
        // Try template version (also 1024x1024)
        let templateURL = bundle.appendingPathComponent("../Icons/MenuBarIcon_template.png")
        if FileManager.default.fileExists(atPath: templateURL.path),
           let image = NSImage(contentsOf: templateURL) {
            return image
        }
        
        return nil
    }
}

#Preview("Selection Overlay - Idle") {
    SelectionOverlayView(
        onSelectionComplete: { rect in
            print("Selection completed: \(rect)")
        },
        onCancel: {
            print("Selection cancelled")
        }
    )
    .frame(width: 1920, height: 1080)
}

#Preview("Selection Overlay - Active Selection") {
    struct PreviewWrapper: View {
        @State private var startPoint: CGPoint = CGPoint(x: 400, y: 300)
        @State private var currentPoint: CGPoint = CGPoint(x: 800, y: 600)
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.3)
                    
                    // Selection rectangle
                    let rect = CGRect(
                        x: min(startPoint.x, currentPoint.x),
                        y: min(startPoint.y, currentPoint.y),
                        width: abs(currentPoint.x - startPoint.x),
                        height: abs(currentPoint.y - startPoint.y)
                    )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Instructions
                    VStack(spacing: 8) {
                        // App icon - use high resolution source image
                        Group {
                            if let iconImage = loadHighResIconForPreview() {
                                Image(nsImage: iconImage)
                                    .renderingMode(.template)
                                    .resizable()
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .scaledToFit()
                                    .foregroundColor(.white)
                            } else {
                                Image("MenuBarIcon")
                                    .renderingMode(.template)
                                    .resizable()
                                    .interpolation(.high)
                                    .antialiased(true)
                                    .scaledToFit()
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 120, height: 120)
                        
                        Text("Select area to translate")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        Text("Press ESC to cancel")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
        .frame(width: 1920, height: 1080)
}

// Helper function for preview to load high-res icon
private func loadHighResIconForPreview() -> NSImage? {
    // Try loading from bundle resources first
    if let image = NSImage(named: "MenuBarIcon_source") {
        return image
    }
    
    // Try loading from the Icons folder in the project
    guard let bundle = Bundle.main.resourceURL else { return nil }
    
    // Try source image (1024x1024)
    let sourceURL = bundle.appendingPathComponent("../Icons/MenuBarIcon_source.png")
    if FileManager.default.fileExists(atPath: sourceURL.path),
       let image = NSImage(contentsOf: sourceURL) {
        return image
    }
    
    // Try template version (also 1024x1024)
    let templateURL = bundle.appendingPathComponent("../Icons/MenuBarIcon_template.png")
    if FileManager.default.fileExists(atPath: templateURL.path),
       let image = NSImage(contentsOf: templateURL) {
        return image
    }
    
    return nil
}

