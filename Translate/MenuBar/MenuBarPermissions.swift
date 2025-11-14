//
//  MenuBarPermissions.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit
import AVFoundation
import ScreenCaptureKit

class MenuBarPermissions {
    static func checkScreenRecordingPermission() async -> Bool {
        // Check ScreenCaptureKit permission by attempting to get shareable content
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            // Check if it's a TCC permission error
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" {
                if nsError.code == -3801 {
                    // User declined TCC permission
                    print("⚠️ [MenuBarPermissions] Screen recording permission denied")
                    return false
                }
            }
            print("⚠️ [MenuBarPermissions] Screen recording permission check error: \(error)")
            return false
        }
    }
    
    static func requestScreenRecordingPermission() async {
        // Request screen recording permission by attempting to access
        // This will trigger the system permission dialog if not already granted
        do {
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print("✅ [MenuBarPermissions] Screen recording permission granted")
        } catch {
            print("⚠️ [MenuBarPermissions] Screen recording permission request failed: \(error)")
        }
    }
    
    static func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "This app needs screen recording permission to capture and translate text.\n\nPlease grant permission in System Settings:\n1. Open System Settings\n2. Go to Privacy & Security\n3. Select Screen Recording\n4. Enable Translation Marks"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Screen Recording
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    static func checkDocumentsFolderAccess() -> Bool {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let screenshotsFolder = homeDirectory.appendingPathComponent("Documents/Screenshots")
        
        // Try to create the folder to test access
        do {
            if !fileManager.fileExists(atPath: screenshotsFolder.path) {
                try fileManager.createDirectory(at: screenshotsFolder, withIntermediateDirectories: true, attributes: nil)
            }
            return true
        } catch {
            return false
        }
    }
    
}

