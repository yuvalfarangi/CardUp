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
    
    /// Official Apple Wallet strip image dimensions for Generic passes
    /// Note: Generic passes use a different aspect ratio than store cards
    /// Store cards use 1125x369 (@3x) with 3:1 ratio
    /// Generic passes use 1125x432 (@3x) with approximately 2.6:1 ratio
    enum StripDimensions {
        // @1x resolution (base)
        static let width1x: CGFloat = 375
        static let height1x: CGFloat = 144
        
        // @2x resolution
        static let width2x: CGFloat = 750
        static let height2x: CGFloat = 288
        
        // @3x resolution (recommended for best quality)
        static let width3x: CGFloat = 1125
        static let height3x: CGFloat = 432
        
        /// Aspect ratio for Generic pass strip images (approximately 2.604:1)
        static let aspectRatio: CGFloat = width3x / height3x
    }
    
    // MARK: - Image Validation
    
    /// Validates if an image meets strip image requirements for Generic passes
    /// - Parameter image: The image to validate
    /// - Returns: Validation result with details
    static func validateStripImage(_ image: UIImage) -> ValidationResult {
        guard let cgImage = image.cgImage else {
            return .invalid(reason: "Unable to process image")
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let actualRatio = width / height
        
        // Check if aspect ratio is approximately 2.604:1 (1125:432)
        let expectedRatio = StripDimensions.aspectRatio
        let tolerance: CGFloat = 0.1 // 10% tolerance for flexibility
        
        guard abs(actualRatio - expectedRatio) / expectedRatio <= tolerance else {
            let expectedRatioFormatted = String(format: "%.1f:1", expectedRatio)
            let actualRatioFormatted = String(format: "%.1f:1", actualRatio)
            return .invalid(reason: "Aspect ratio should be \(expectedRatioFormatted) (1125×432). Current: \(Int(width))×\(Int(height)) (\(actualRatioFormatted))")
        }
        
        // Check minimum resolution (at least @2x for good quality)
        let minWidth = StripDimensions.width2x // At least @2x (750px)
        if width < minWidth {
            return .warning(reason: "Resolution is low. Recommended minimum: 750×288 pixels. Current: \(Int(width))×\(Int(height))")
        }
        
        // Check if at optimal @3x resolution (1125x432)
        if width >= StripDimensions.width3x && height >= StripDimensions.height3x {
            return .valid(message: "Perfect! Image meets @3x resolution (1125×432)")
        } else if width >= StripDimensions.width2x && height >= StripDimensions.height2x {
            return .valid(message: "Good quality @2x resolution (750×288)")
        } else {
            return .valid(message: "Acceptable @1x resolution (375×144)")
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
                title: "Generic Pass Strip",
                tips: [
                    "Use 1125×432 resolution (@3x) for best quality",
                    "Maintain approximately 2.6:1 aspect ratio",
                    "Keep center area clear for card information",
                    "Reserve left side (100px) for logo overlay",
                    "Ensure high contrast with text color",
                    "Use PNG format with sRGB color space",
                    "Consider brand colors and subtle patterns"
                ],
                examples: [
                    "Membership: Brand gradient with subtle texture",
                    "Loyalty: Vibrant colors reflecting brand identity",
                    "ID Card: Professional solid color or minimal gradient"
                ]
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
                    "Use 1125×432 resolution (@3x) for Generic passes",
                    "Maintain approximately 2.6:1 aspect ratio",
                    "Keep center and left areas clear for overlays",
                    "Ensure good contrast for text overlays",
                    "Use PNG format with sRGB color space",
                    "Consider how design works with logo and text"
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
                    // Updated dimensions for Generic pass strip (1125x432 @3x = 375x144 @1x)
                    .frame(width: 375, height: 144)
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
