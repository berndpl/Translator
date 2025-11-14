//
//  ScreenCaptureOverlay.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit
import CoreGraphics

class ScreenCaptureOverlay {
    func drawTextRegionsOnImage(image: NSImage, regions: [TextRegion]) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("⚠️ Failed to get CGImage from NSImage, returning original")
            return image
        }
        
        let imageSize = image.size
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        
        print("Creating bitmap context: \(width)x\(height)")
        
        // Create a bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("⚠️ Failed to create CGContext, returning original")
            return image
        }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw rectangles for each text region
        for (index, region) in regions.enumerated() {
            let normalizedRect = region.boundingBox
            
            // Convert normalized coordinates (0.0-1.0, bottom-left origin) to image coordinates (top-left origin)
            let rect = CGRect(
                x: normalizedRect.origin.x * CGFloat(width),
                y: (1.0 - normalizedRect.origin.y - normalizedRect.height) * CGFloat(height),
                width: normalizedRect.width * CGFloat(width),
                height: normalizedRect.height * CGFloat(height)
            )
            
            print("Drawing region \(index + 1): '\(region.text)' at \(rect)")
            
            // Draw green rectangle border
            context.setStrokeColor(NSColor.green.cgColor)
            context.setLineWidth(3.0)
            context.stroke(rect)
            
            // Draw semi-transparent fill
            context.setFillColor(NSColor.green.withAlphaComponent(0.2).cgColor)
            context.fill(rect)
            
            // Draw text label above the rectangle using NSGraphicsContext
            let text = region.text as NSString
            let font = NSFont.systemFont(ofSize: 12)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.green.withAlphaComponent(0.9)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: rect.origin.x,
                y: rect.maxY + 5,
                width: max(textSize.width, rect.width),
                height: textSize.height + 4
            )
            
            // Draw background for text
            let bgRect = CGRect(
                x: textRect.origin.x - 2,
                y: textRect.origin.y - 2,
                width: textRect.width + 4,
                height: textRect.height + 4
            )
            
            // Flip coordinate system for text drawing (NSGraphicsContext uses top-left origin)
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw background
            context.setFillColor(NSColor.green.withAlphaComponent(0.9).cgColor)
            let flippedBgRect = CGRect(
                x: bgRect.origin.x,
                y: CGFloat(height) - bgRect.maxY,
                width: bgRect.width,
                height: bgRect.height
            )
            context.fill(flippedBgRect)
            
            // Draw text
            let flippedTextRect = CGRect(
                x: textRect.origin.x,
                y: CGFloat(height) - textRect.maxY,
                width: textRect.width,
                height: textRect.height
            )
            
            // Use NSString drawing with NSGraphicsContext
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext
            text.draw(in: flippedTextRect, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
            
            context.restoreGState()
        }
        
        // Create new image from context
        guard let newCGImage = context.makeImage() else {
            print("⚠️ Failed to create CGImage from context, returning original")
            return image
        }
        
        let newImage = NSImage(cgImage: newCGImage, size: imageSize)
        print("✅ Successfully created annotated image")
        return newImage
    }
}

