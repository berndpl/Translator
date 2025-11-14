//
//  ScreenCaptureTextDetector.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import Vision
import AppKit

struct TextRegion {
    let text: String
    let boundingBox: CGRect // Normalized coordinates (0.0 to 1.0)
}

class ScreenCaptureTextDetector {
    func extractTextRegions(from image: NSImage) async -> [TextRegion] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let textRegions = observations.compactMap { observation -> TextRegion? in
                    guard let text = observation.topCandidates(1).first?.string,
                          !text.isEmpty else {
                        return nil
                    }
                    
                    // Get bounding box in normalized coordinates (0.0 to 1.0)
                    let boundingBox = observation.boundingBox
                    return TextRegion(text: text, boundingBox: boundingBox)
                }
                
                continuation.resume(returning: textRegions)
            }
            
            // Use accurate recognition for better results
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Set Japanese as the primary recognition language
            // Vision framework supports Japanese text recognition (ja-JP)
            // This improves accuracy for Japanese text detection
            request.recognitionLanguages = ["ja-JP", "ja"]
            
            print("🔤 Configured text recognition for Japanese (ja-JP)")
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    func extractAllText(from image: NSImage) async -> String {
        let regions = await extractTextRegions(from: image)
        return regions.map { $0.text }.joined(separator: " ")
    }
    
    // Alias for compatibility with OCRService
    func extractText(from image: NSImage) async -> String? {
        let text = await extractAllText(from: image)
        return text.isEmpty ? nil : text
    }
}

