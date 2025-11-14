//
//  SelectionOverlayView.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI
import AppKit

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
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(26)
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

