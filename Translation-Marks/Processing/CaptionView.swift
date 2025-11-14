//
//  CaptionView.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 14.11.2025.
//

import SwiftUI
import AppKit

/// SwiftUI view for caption display
/// Design this view using Xcode previews
struct CaptionView: View {
    let text: String
    @State private var isVisible: Bool = false
    @State private var displayText: String = ""
    
    // Helper function to get JetBrains font with fallback
    private func getJetBrainsFont(size: CGFloat) -> Font {
        // Try different JetBrains font variants
        if let font = NSFont(name: "JetBrains Mono", size: size) {
            return Font(font)
        } else if let font = NSFont(name: "JetBrainsMono-Regular", size: size) {
            return Font(font)
        } else if let font = NSFont(name: "JetBrainsMono", size: size) {
            return Font(font)
        } else {
            // Fallback to system monospaced font
            return .system(size: size, weight: .medium, design: .monospaced)
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(displayText.isEmpty ? " " : displayText)  // Use space to maintain size when empty
                .font(getJetBrainsFont(size: 16))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)  // Allow unlimited lines
                .lineSpacing(8)  // Increased line spacing for better readability
                .fixedSize(horizontal: false, vertical: true)  // Allow vertical expansion
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 40)
                .opacity(isVisible ? 1.0 : 0.0)
                .offset(y: isVisible ? 0 : 10)  // Move up when appearing, down when disappearing
                .animation(.easeInOut(duration: 0.3), value: isVisible)
                .frame(minHeight: 80)  // Maintain minimum height to prevent collapse
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            // Set display text immediately
            displayText = text
            // Animate in: fade in + move up
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        }
        .onChange(of: text) { oldValue, newValue in
            if newValue.isEmpty {
                // Disappear: fade out + move down (but keep text to maintain size)
                withAnimation(.easeIn(duration: 0.3)) {
                    isVisible = false
                }
                // Clear display text after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    displayText = ""
                }
            } else {
                // Update display text immediately to maintain size
                displayText = newValue
                if !isVisible {
                    // Appear: fade in + move up
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = true
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        // Simulate dark background for preview
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        CaptionView(text: "This is a sample caption text that will be displayed when speech is active")
    }
    .frame(width: 800, height: 600)
}

#Preview("Long Text") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        CaptionView(text: "This is a much longer caption text that might wrap to multiple lines and should still look good in the preview")
    }
    .frame(width: 800, height: 600)
}

#Preview("Short Text") {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        CaptionView(text: "Short")
    }
    .frame(width: 800, height: 600)
}

