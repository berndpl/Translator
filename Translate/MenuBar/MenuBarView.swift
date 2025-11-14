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
            // Voice Selection
        VStack {
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

#Preview("Ready") {
    MenuBarView()
        .environmentObject(MarksManager())
}

#Preview("Processing") {
    let manager = MarksManager()
    manager.isProcessing = true
    manager.statusMessage = "Translating from Japanese to English..."
    return MenuBarView()
        .environmentObject(manager)
}

