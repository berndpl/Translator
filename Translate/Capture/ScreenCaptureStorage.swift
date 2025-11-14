//
//  ScreenCaptureStorage.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit

class ScreenCaptureStorage {
    private let defaultFolder = "Documents/Screenshots"
    
    func saveScreenshot(_ image: NSImage) {
        let folderURL = getScreenshotsFolder()
        
        // Create the folder if it doesn't exist
        do {
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("Failed to create screenshots folder: \(error)")
            return
        }
        
        // Create filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Translate \(timestamp).png"
        let fileURL = folderURL.appendingPathComponent(filename)
        
        // Convert NSImage to PNG data and save
        print("Converting image to PNG...")
        print("Image size: \(image.size)")
        
        guard let tiffData = image.tiffRepresentation else {
            print("❌ Failed to get TIFF representation from image")
            return
        }
        
        guard let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            print("❌ Failed to create NSBitmapImageRep from TIFF data")
            return
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("❌ Failed to convert bitmap to PNG data")
            return
        }
        
        print("PNG data size: \(pngData.count) bytes")
        print("Saving to: \(fileURL.path)")
        
        do {
            try pngData.write(to: fileURL)
            print("✅ Screenshot saved successfully to: \(fileURL.path)")
            
            // Verify file exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64
                print("✅ File verified, size: \(fileSize ?? 0) bytes")
            } else {
                print("⚠️ Warning: File was written but doesn't exist at path")
            }
        } catch {
            print("❌ Failed to save screenshot: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    func getScreenshotsFolder() -> URL {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(defaultFolder)
    }
}

