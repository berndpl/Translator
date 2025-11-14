//
//  MenuBarView.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var manager: MarksManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundColor(.blue)
                Text("Translation Marks")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(manager.statusMessage)
                        .font(.caption)
                        .foregroundColor(manager.isProcessing ? .blue : .primary)
                }
                .padding(.horizontal)
                
                if manager.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.horizontal)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut: ⌘⌃⌥T")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Text("Select area to translate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VoicePickerView()
                    .padding(.horizontal)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Debug Toggles Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Toggles:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Toggle("Capture", isOn: $manager.enableCapture)
                    .padding(.horizontal)
                Toggle("Text Detection", isOn: $manager.enableTextDetection)
                    .padding(.horizontal)
                Toggle("Draw Overlays on Image", isOn: $manager.enableOverlayDrawing)
                    .padding(.horizontal)
                Toggle("Save Screenshot", isOn: $manager.enableScreenshotSaving)
                    .padding(.horizontal)
                Toggle("Show Overlay Window", isOn: $manager.enableOverlayDisplay)
                    .padding(.horizontal)
                Toggle("Read Original", isOn: $manager.enableOriginalTextSpeech)
                    .padding(.horizontal)
                Toggle("Translation", isOn: $manager.enableTranslation)
                    .padding(.horizontal)
                Toggle("Read Translation", isOn: $manager.enableTranslationSpeech)
                    .padding(.horizontal)
                Toggle("Show Captions", isOn: $manager.enableCaptions)
                    .padding(.horizontal)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            Button(action: {
                openScreenshotsFolder()
            }) {
                HStack {
                    Image(systemName: "folder")
                    Text("Open Screenshots Folder")
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 250)
        .padding(.vertical, 8)
    }
    
    private func openScreenshotsFolder() {
        let storage = ScreenCaptureStorage()
        let folderURL = storage.getScreenshotsFolder()
        
        // Create the folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Open in Finder
        FolderOpener.open(folderURL)
    }
}

