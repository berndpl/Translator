//
//  TextRegionsOverlayView.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI

struct TextRegionsOverlayView: View {
    let image: NSImage
    let regions: [TextRegion]
    let onClose: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Display the image
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Draw bounding boxes over detected text regions
                ForEach(Array(regions.enumerated()), id: \.offset) { index, region in
                    TextRegionOverlay(
                        region: region,
                        imageSize: image.size,
                        geometrySize: geometry.size
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .overlay(
                // Close button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button("Close") {
                            onClose()
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                    Spacer()
                }
            )
        }
    }
}

struct TextRegionOverlay: View {
    let region: TextRegion
    let imageSize: CGSize
    let geometrySize: CGSize
    
    var body: some View {
        let displayedRect = calculateDisplayedRect()
        
        Rectangle()
            .fill(Color.clear)
            .border(Color.green, width: 3)
            .frame(width: displayedRect.width, height: displayedRect.height)
            .position(
                x: displayedRect.midX,
                y: displayedRect.midY
            )
            .overlay(
                // Show text label above the rectangle
                Text(region.text)
                    .font(.caption)
                    .padding(4)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .fixedSize(horizontal: true, vertical: false)
                    .position(
                        x: displayedRect.midX,
                        y: max(10, displayedRect.minY - 15)
                    )
            )
    }
    
    private func calculateDisplayedRect() -> CGRect {
        // Calculate the actual image size within the geometry
        let imageAspectRatio = imageSize.width / imageSize.height
        let geometryAspectRatio = geometrySize.width / geometrySize.height
        
        let displayedImageSize: CGSize
        let imageOffset: CGPoint
        
        if imageAspectRatio > geometryAspectRatio {
            // Image is wider - fit to width
            displayedImageSize = CGSize(
                width: geometrySize.width,
                height: geometrySize.width / imageAspectRatio
            )
            imageOffset = CGPoint(
                x: 0,
                y: (geometrySize.height - displayedImageSize.height) / 2
            )
        } else {
            // Image is taller - fit to height
            displayedImageSize = CGSize(
                width: geometrySize.height * imageAspectRatio,
                height: geometrySize.height
            )
            imageOffset = CGPoint(
                x: (geometrySize.width - displayedImageSize.width) / 2,
                y: 0
            )
        }
        
        // Convert normalized coordinates to actual image coordinates
        let normalizedRect = region.boundingBox
        let imageRect = CGRect(
            x: normalizedRect.origin.x * imageSize.width,
            y: (1.0 - normalizedRect.origin.y - normalizedRect.height) * imageSize.height,
            width: normalizedRect.width * imageSize.width,
            height: normalizedRect.height * imageSize.height
        )
        
        // Scale to displayed size
        let scaleX = displayedImageSize.width / imageSize.width
        let scaleY = displayedImageSize.height / imageSize.height
        
        return CGRect(
            x: imageOffset.x + imageRect.origin.x * scaleX,
            y: imageOffset.y + imageRect.origin.y * scaleY,
            width: imageRect.width * scaleX,
            height: imageRect.height * scaleY
        )
    }
    
    private func convertNormalizedRect(_ normalizedRect: CGRect, to size: CGSize) -> CGRect {
        // Vision framework uses bottom-left origin, SwiftUI uses top-left
        // Normalized coordinates are 0.0 to 1.0
        let x = normalizedRect.origin.x * size.width
        let y = (1.0 - normalizedRect.origin.y - normalizedRect.height) * size.height
        let width = normalizedRect.width * size.width
        let height = normalizedRect.height * size.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

