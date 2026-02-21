//
//  StripImageProcessor.swift
//  CardUp
//
//  Created by Assistant on 21/02/2026.
//

import UIKit
import SwiftUI

/// Processes and validates strip images for Apple Wallet passes
struct StripImageProcessor {
    
    // MARK: - Constants
    
    /// Official Apple Wallet strip image dimensions
    enum StripDimensions {
        static let width1x: CGFloat = 375
        static let height1x: CGFloat = 123
        
        static let width2x: CGFloat = 750
        static let height2x: CGFloat = 246
        
        static let width3x: CGFloat = 1125
        static let height3x: CGFloat = 369
        
        /// Aspect ratio for strip images (3:1)
        static let aspectRatio: CGFloat = width3x / height3x
    }
    
    // MARK: - Image Validation
    
    /// Validates if an image meets strip image requirements
    /// - Parameter image: The image to validate
    /// - Returns: Validation result with details
    static func validateStripImage(_ image: UIImage) -> ValidationResult {
        guard let cgImage = image.cgImage else {
            return .invalid(reason: "Unable to process image")
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let actualRatio = width / height
        
        // Check if aspect ratio is approximately 3:1
        let expectedRatio = StripDimensions.aspectRatio
        let tolerance: CGFloat = 0.05 // 5% tolerance
        
        guard abs(actualRatio - expectedRatio) / expectedRatio <= tolerance else {
            return .invalid(reason: "Aspect ratio should be 3:1 (1125×369). Current: \(Int(width))×\(Int(height))")
        }
        
        // Check minimum resolution
        let minWidth = StripDimensions.width2x // At least @2x
        if width < minWidth {
            return .warning(reason: "Resolution is low. Recommended minimum: 750×246 pixels. Current: \(Int(width))×\(Int(height))")
        }
        
        // Check if at optimal @3x resolution
        if width >= StripDimensions.width3x && height >= StripDimensions.height3x {
            return .valid(message: "Perfect! Image meets @3x resolution (1125×369)")
        } else if width >= StripDimensions.width2x && height >= StripDimensions.height2x {
            return .valid(message: "Good quality @2x resolution (750×246)")
        } else {
            return .valid(message: "Acceptable @1x resolution (375×123)")
        }
    }
    
    enum ValidationResult {
        case valid(message: String)
        case warning(reason: String)
        case invalid(reason: String)
        
        var isValid: Bool {
            switch self {
            case .valid, .warning:
                return true
            case .invalid:
                return false
            }
        }
        
        var message: String {
            switch self {
            case .valid(let message):
                return message
            case .warning(let reason):
                return "⚠️ " + reason
            case .invalid(let reason):
                return "❌ " + reason
            }
        }
        
        var icon: String {
            switch self {
            case .valid:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .invalid:
                return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .valid:
                return .green
            case .warning:
                return .orange
            case .invalid:
                return .red
            }
        }
    }
    
    // MARK: - Image Processing
    
    /// Processes an image to meet strip image requirements
    /// - Parameters:
    ///   - image: The source image
    ///   - targetResolution: Target resolution (1x, 2x, or 3x)
    /// - Returns: Processed image or nil if processing fails
    static func processStripImage(
        _ image: UIImage,
        targetResolution: Resolution = .threeX
    ) -> UIImage? {
        let targetSize: CGSize
        
        switch targetResolution {
        case .oneX:
            targetSize = CGSize(width: StripDimensions.width1x, height: StripDimensions.height1x)
        case .twoX:
            targetSize = CGSize(width: StripDimensions.width2x, height: StripDimensions.height2x)
        case .threeX:
            targetSize = CGSize(width: StripDimensions.width3x, height: StripDimensions.height3x)
        }
        
        return resizeAndCropImage(image, to: targetSize)
    }
    
    enum Resolution {
        case oneX, twoX, threeX
    }
    
    /// Generates all three resolution variants for a strip image
    /// - Parameter image: The source image
    /// - Returns: Dictionary with all three variants
    static func generateAllResolutions(_ image: UIImage) -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        
        if let image1x = processStripImage(image, targetResolution: .oneX) {
            results["strip.png"] = image1x
        }
        
        if let image2x = processStripImage(image, targetResolution: .twoX) {
            results["strip@2x.png"] = image2x
        }
        
        if let image3x = processStripImage(image, targetResolution: .threeX) {
            results["strip@3x.png"] = image3x
        }
        
        return results
    }
    
    // MARK: - Private Helpers
    
    private static func resizeAndCropImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        let scale = max(
            size.width / image.size.width,
            size.height / image.size.height
        )
        
        let scaledWidth = image.size.width * scale
        let scaledHeight = image.size.height * scale
        
        let x = (scaledWidth - size.width) / 2.0
        let y = (scaledHeight - size.height) / 2.0
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        return renderer.image { context in
            let drawRect = CGRect(
                x: -x,
                y: -y,
                width: scaledWidth,
                height: scaledHeight
            )
            image.draw(in: drawRect)
        }
    }
    
    // MARK: - Design Guidelines
    
    /// Provides design tips for strip images based on pass type
    static func designGuidelines(for passType: String) -> DesignGuidelines {
        switch passType.lowercased() {
        case "storecard":
            return DesignGuidelines(
                title: "Store Card Strip",
                tips: [
                    "Use brand colors and subtle gradients",
                    "Keep center area clear for customer name",
                    "Reserve left side (100px) for logo overlay",
                    "Ensure high contrast with white text",
                    "Consider seasonal or promotional themes"
                ],
                examples: [
                    "Coffee shop: Warm brown gradient with subtle coffee bean texture",
                    "Retail: Premium gold to champagne gradient with subtle patterns",
                    "Tech store: Modern blue to purple gradient with geometric elements"
                ]
            )
            
        case "generic":
            return DesignGuidelines(
                title: "Generic Pass (No Strip)",
                tips: [
                    "Generic passes don't use strip images",
                    "Use background.png instead for full-card background",
                    "Consider using icon.png and logo.png for branding"
                ],
                examples: []
            )
            
        case "coupon":
            return DesignGuidelines(
                title: "Coupon Strip",
                tips: [
                    "Make it eye-catching and promotional",
                    "Use vibrant colors that grab attention",
                    "Consider discount-themed elements (sale tags, stars)",
                    "Keep text overlay areas clear"
                ],
                examples: [
                    "20% OFF: Vibrant red gradient with star elements in corners",
                    "Spring Sale: Fresh green to yellow gradient with floral elements",
                    "Black Friday: Bold black to dark red with geometric patterns"
                ]
            )
            
        case "eventticket":
            return DesignGuidelines(
                title: "Event Ticket Strip",
                tips: [
                    "Reflect the event theme and atmosphere",
                    "Use event branding colors",
                    "Consider venue or event imagery (subtle)",
                    "Maintain professional appearance"
                ],
                examples: [
                    "Concert: Dynamic gradient with music wave patterns",
                    "Sports event: Team colors with subtle stadium texture",
                    "Conference: Professional gradient with geometric patterns"
                ]
            )
            
        default:
            return DesignGuidelines(
                title: "Strip Image Guidelines",
                tips: [
                    "Use 1125×369 resolution (@3x)",
                    "Maintain 3:1 aspect ratio",
                    "Keep center and left areas clear",
                    "Ensure good contrast for text overlays",
                    "Use PNG format with sRGB color space"
                ],
                examples: []
            )
        }
    }
    
    struct DesignGuidelines {
        let title: String
        let tips: [String]
        let examples: [String]
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
struct StripImagePreviewView: View {
    let image: UIImage
    let companyName: String
    let cardName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Strip Image Preview")
                .font(.headline)
            
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 375, height: 123)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(alignment: .top, spacing: 12) {
                    // Logo placeholder
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(companyName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(cardName)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 24)
                    
                    Spacer()
                }
            }
            
            let validation = StripImageProcessor.validateStripImage(image)
            
            HStack(spacing: 8) {
                Image(systemName: validation.icon)
                    .foregroundColor(validation.color)
                Text(validation.message)
                    .font(.caption)
            }
        }
        .padding()
    }
}
#endif
