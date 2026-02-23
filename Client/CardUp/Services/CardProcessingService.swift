//
//  CardProcessingService.swift
//  CardUp
//
//  Created by Yuval Farangi on 22/02/2026.
//  Updated by Yuval Farangi on 23/02/2026 - Integrated Gemini AI
//

import Foundation
import UIKit
import SwiftUI

/// A comprehensive service for processing physical card images into Apple Wallet passes using AI-powered analysis.
///
/// `CardProcessingService` is the central orchestrator for transforming photos of physical cards (loyalty cards,
/// membership cards, coupons, etc.) into fully functional Apple Wallet passes. It leverages Google's Gemini AI
/// through a server API to extract card information, detect visual elements, and generate appropriate pass designs.
///
/// ## Features
///
/// The service provides a complete pipeline for card processing with the following capabilities:
///
/// - **AI-Powered Card Analysis**: Uses Google Gemini AI to extract structured data from card images
/// - **AI-Powered Design Generation**: Generates professional banner images using a separate Gemini endpoint
/// - **Barcode Detection**: Automatically identifies and extracts barcode formats (QR, PDF417, Code128, Aztec)
/// - **Color Analysis**: Extracts dominant colors for consistent visual styling
/// - **Pass Generation**: Creates Apple Wallet-compatible passes with all extracted information
/// - **Progress Tracking**: Provides real-time progress updates during the multi-step processing pipeline
///
/// ## Usage
///
/// The typical workflow involves calling `generateWalletPass(from:for:)` with a card image and a Card model:
///
/// ```swift
/// let processingService = CardProcessingService()
///
/// // Process a card image
/// await processingService.generateWalletPass(from: cardImage, for: card)
///
/// // Monitor progress
/// if processingService.isProcessing {
///     Text("Processing: \(Int(processingService.processingProgress * 100))%")
///     Text(processingService.processingStatus)
/// }
///
/// // Check for errors
/// if let error = processingService.error {
///     Text("Error: \(error)")
/// }
///
/// // Access results
/// if let passData = processingService.generatedPassData {
///     // Pass is ready to be added to Apple Wallet
/// }
/// ```
///
/// ## Processing Pipeline
///
/// The service executes the following steps in sequence:
///
/// 1. **Image Preparation (10%)**: Compresses and validates the input image
/// 2. **AI Data Extraction (30%)**: Sends image to `/api/gemini/cardDataExtraction` for structured data
/// 3. **Card Update (45%)**: Updates the Card model with extracted data
/// 4. **AI Design Generation (60%)**: Calls `/api/gemini/cardDesignGenerating` for banner image
/// 5. **Design Download (65%)**: Retrieves generated design image
/// 6. **Color Extraction (70%)**: Analyzes image for dominant colors
/// 7. **Logo Processing (80%)**: Extracts and processes logo region
/// 8. **Pass Generation (95%)**: Creates final .pkpass file
/// 9. **Completion (100%)**: Pass is ready for Apple Wallet
///
/// ## Architecture
///
/// - **Observable Pattern**: Uses Swift's `@Observable` macro for seamless SwiftUI integration
/// - **Async/Await**: All processing operations are fully asynchronous using Swift Concurrency
/// - **Error Handling**: Comprehensive error types with user-friendly messages
/// - **Main Actor Isolation**: UI-related properties are properly isolated to the main thread
///
/// ## Integration Points
///
/// This service coordinates with several other components:
///
/// - `ServerApi`: Handles communication with the Gemini AI backend (two separate endpoints)
/// - `PassKitIntegrator`: Generates actual .pkpass files for Apple Wallet
/// - `Card` model: SwiftData model storing all card information
/// - `GeminiCardAnalysisResponse`: Structured response from AI data extraction
/// - `CardDesignResponse`: Response from AI design generation
///
/// ## Performance Considerations
///
/// - Images are automatically compressed to under 5MB for efficient network transfer
/// - Color extraction is performed on a background thread to avoid blocking
/// - Progress updates ensure responsive UI during long-running operations
///
/// ## Thread Safety
///
/// This class is designed to be used from the main actor. All public methods marked with `@MainActor`
/// ensure thread-safe property updates and proper UI synchronization.
///
/// - Warning: The service maintains mutable state and is not designed for concurrent processing of
///            multiple cards. Create separate instances if parallel processing is needed.
///
/// - SeeAlso: `ServerApi`, `PassKitIntegrator`, `Card`, `GeminiCardAnalysisResponse`, `CardDesignResponse`
@Observable
final class CardProcessingService {
    // MARK: - Public Properties
    
    /// Indicates whether a card processing operation is currently in progress.
    ///
    /// This property is automatically updated throughout the processing pipeline and can be
    /// observed in SwiftUI views to show loading states or disable user interactions.
    ///
    /// - Note: This property is `@MainActor` isolated and safe to observe in views.
    var isProcessing: Bool = false
    
    /// The complete structured data extracted from the card image by Gemini AI.
    ///
    /// This property contains the full response from the Gemini API including:
    /// - Card type/format recommendation
    /// - Extracted text fields (name, membership number, etc.)
    /// - Barcode information (format and data)
    /// - Color scheme (background, foreground, label colors)
    /// - Generated design image
    ///
    /// The data is structured according to Apple PassKit field conventions and is ready
    /// to be used for pass generation.
    ///
    /// - SeeAlso: `GeminiCardAnalysisResponse`
    var extractedData: GeminiCardAnalysisResponse?
    
    /// The final generated Apple Wallet pass file data (.pkpass).
    ///
    /// This property contains the complete, signed .pkpass file ready to be added to Apple Wallet.
    /// The data can be presented using `PKAddPassesViewController` or saved to disk.
    ///
    /// - Note: This property is only populated after successful completion of all processing steps.
    var generatedPassData: Data?
    
    /// A user-friendly error message if processing fails.
    ///
    /// When an error occurs during any step of the processing pipeline, this property is set
    /// with a descriptive message suitable for display to the user. If processing is successful,
    /// this property remains `nil`.
    ///
    /// Common error scenarios include:
    /// - Network connectivity issues
    /// - Invalid or unreadable card images
    /// - Server-side processing failures
    /// - Insufficient image quality
    var error: String?
    
    /// The current progress of the processing operation (0.0 to 1.0).
    ///
    /// This property provides fine-grained progress tracking through the multi-step processing
    /// pipeline. It can be used to drive progress bars or percentage indicators in the UI.
    ///
    /// Progress milestones:
    /// - 0.10: Image preparation complete
    /// - 0.30: AI analysis complete
    /// - 0.50: Design image downloaded
    /// - 0.60: Card model updated
    /// - 0.70: Color extraction complete
    /// - 0.80: Logo processing complete
    /// - 0.95: Pass generation complete
    /// - 1.00: All operations complete
    var processingProgress: Double = 0.0
    
    /// A human-readable description of the current processing step.
    ///
    /// This property provides contextual information about what the service is currently doing,
    /// suitable for display to the user. Examples include:
    /// - "Preparing image..."
    /// - "Analyzing card with AI..."
    /// - "Downloading design..."
    /// - "Generating wallet pass..."
    ///
    /// The status updates in sync with `processingProgress`.
    var processingStatus: String = ""
    
    // MARK: - Private Properties
    
    /// The shared server API instance for communicating with the backend.
    ///
    /// This property provides access to the Gemini AI analysis endpoint and other server
    /// functionality required for card processing.
    private let serverApi = ServerApi.shared
    
    /// The PassKit integration service for generating .pkpass files.
    ///
    /// This property handles the final step of creating Apple Wallet-compatible pass files
    /// from the extracted card data.
    private let passKitIntegrator = PassKitIntegrator()
    
    // MARK: - Main Processing Pipeline (Gemini-Powered)
    
    /// Generates a custom card design/banner image using Gemini AI
    ///
    /// This method is separate from the main card processing pipeline and can be called independently
    /// to generate or regenerate the visual design/banner for a card. It leverages Gemini AI's
    /// image generation capabilities to create a professional banner image based on card details.
    ///
    /// ## Use Cases
    ///
    /// - Generate initial banner during card creation
    /// - Regenerate banner after editing card details (colors, organization name, etc.)
    /// - Create banner when original card image didn't have good visual elements
    /// - Update banner with new branding or style preferences
    ///
    /// ## Design Image Specifications
    ///
    /// The generated image should be:
    /// - **Size**: 1125 x 432 pixels (@3x resolution) or 750 x 288 (@2x)
    /// - **Format**: PNG or JPEG
    /// - **Usage**: Displayed as the strip/banner image in Apple Wallet passes
    ///
    /// ## Processing Steps
    ///
    /// 1. Extracts relevant card details (organization, colors, description)
    /// 2. Builds a CardDesignRequest with styling information
    /// 3. Sends request to Gemini AI design generation endpoint
    /// 4. Downloads or decodes the generated design image
    /// 5. Updates the card's bannerImageData property
    ///
    /// ## Error Handling
    ///
    /// If design generation fails, the error is stored in the `error` property and the card's
    /// banner remains unchanged. The card can still be used with just the background color.
    ///
    /// - Parameters:
    ///   - card: The Card model to generate a design for
    ///   - referenceImage: Optional reference image to help guide the design style
    ///
    /// - Note: This method updates observable properties and must be called from the main actor.
    ///
    /// - Example:
    /// ```swift
    /// let service = CardProcessingService()
    /// await service.generateCardDesign(for: card)
    ///
    /// if let error = service.error {
    ///     print("Design generation failed: \(error)")
    /// } else {
    ///     print("Banner image updated successfully")
    /// }
    /// ```
    @MainActor
    func generateCardDesign(for card: Card, referenceImage: UIImage? = nil) async {
        isProcessing = true
        error = nil
        processingProgress = 0.0
        
        do {
            // Step 1: Prepare card details for design generation (20%)
            updateProgress(0.20, status: "Preparing design request...")
            
            let designRequest = CardDesignRequest(
                organizationName: card.organizationName.isEmpty ? nil : card.organizationName,
                description: card.passDescription.isEmpty ? nil : card.passDescription,
                logoText: card.logoText,
                backgroundColor: card.backgroundColor,
                foregroundColor: card.foregroundColor,
                designStyle: nil, // Could be extended to allow user to choose style
                additionalContext: nil
            )
            
            print("🎨 Generating card design:")
            print("   Organization: \(designRequest.organizationName ?? "N/A")")
            print("   Background: \(designRequest.backgroundColor ?? "N/A")")
            print("   Foreground: \(designRequest.foregroundColor ?? "N/A")")
            
            // Step 2: Compress reference image if provided (40%)
            var referenceImageData: Data? = nil
            if let refImage = referenceImage {
                updateProgress(0.40, status: "Preparing reference image...")
                referenceImageData = compressImage(refImage)
            }
            
            // Step 3: Send design generation request to Gemini (60%)
            // Non-fatal: try? means any server/quota error silently skips the banner
            updateProgress(0.60, status: "Generating design with AI...")
            if let designResponse = try? await serverApi.generateCardDesign(
                cardDetails: designRequest,
                imageData: referenceImageData
            ) {
                print("✅ Design generation response received")
                updateProgress(0.80, status: "Downloading design...")
                let designImageData = try? await downloadDesignImage(from: designResponse.designImage)
                updateProgress(1.0, status: "Saving banner image...")
                card.bannerImageData = designImageData
                if let bytes = designImageData {
                    print("✅ Banner image updated: \(bytes.count) bytes")
                } else {
                    print("⚠️ No image data returned — banner will use background color")
                }
            } else {
                updateProgress(1.0, status: "Complete")
                card.bannerImageData = nil
                print("⚠️ Design generation skipped — banner will use background color")
            }

        } catch {
            // Only non-design errors reach here (e.g. image compression failure)
            print("❌ Card design setup failed: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    /// Processes a card image through the complete AI-powered pipeline to generate an Apple Wallet pass.
    ///
    /// This is the main entry point for card processing. It orchestrates the entire workflow from raw
    /// image input to a fully functional Apple Wallet pass. The method handles all intermediate steps
    /// including AI analysis, design generation, color processing, and pass generation.
    ///
    /// ## Processing Steps
    ///
    /// The method executes the following pipeline:
    ///
    /// 1. **Image Preparation**: Validates and compresses the image for network transfer
    /// 2. **AI Analysis**: Sends the image to Gemini AI for structured data extraction (via `/api/gemini/cardDataExtraction`)
    /// 3. **Card Model Update**: Updates the Card model with all extracted information
    /// 4. **Design Generation**: Calls separate Gemini endpoint to generate banner image (via `/api/gemini/cardDesignGenerating`)
    /// 5. **Design Retrieval**: Downloads or decodes the generated design image
    /// 6. **Color Analysis**: Extracts dominant colors if not already provided
    /// 7. **Logo Extraction**: Identifies and processes the logo region
    /// 8. **Pass Generation**: Creates the final .pkpass file
    ///
    /// ## API Endpoints Used
    ///
    /// This method uses two separate Gemini AI endpoints:
    /// - **Card Data Extraction** (`/api/gemini/cardDataExtraction`): Extracts text, barcodes, colors, and field data
    /// - **Design Generation** (`/api/gemini/cardDesignGenerating`): Generates the visual banner/strip image
    ///
    /// ## Progress Tracking
    ///
    /// Throughout execution, the method updates:
    /// - `processingProgress`: Numerical progress from 0.0 to 1.0
    /// - `processingStatus`: Human-readable status messages
    /// - `isProcessing`: Boolean flag indicating active processing
    ///
    /// ## Error Handling
    ///
    /// The method handles various error scenarios:
    /// - Invalid or corrupted images
    /// - Network connectivity issues
    /// - Server-side processing failures
    /// - Data parsing errors
    ///
    /// All errors are caught and converted to user-friendly messages stored in the `error` property.
    ///
    /// ## Side Effects
    ///
    /// This method modifies multiple properties on both the service and the Card model:
    /// - Updates all service state properties (`isProcessing`, `error`, `extractedData`, etc.)
    /// - Modifies the Card model with extracted data
    /// - Downloads and stores images (banner, logo)
    /// - Generates and stores pass data
    ///
    /// - Parameters:
    ///   - image: The UIImage containing the photo of the physical card to process
    ///   - card: The SwiftData Card model to populate with extracted information
    ///
    /// - Note: This method must be called from the main actor context as it updates
    ///         observable properties that may be bound to UI elements.
    ///
    /// - Precondition: The image must be a valid UIImage with readable pixel data
    /// - Postcondition: On success, the card will have all fields populated and `generatedPassData` will contain a valid .pkpass file
    ///
    /// - Example:
    /// ```swift
    /// let service = CardProcessingService()
    /// let cardImage = UIImage(named: "my-card")!
    /// let card = Card()
    ///
    /// await service.generateWalletPass(from: cardImage, for: card)
    ///
    /// if let error = service.error {
    ///     print("Processing failed: \(error)")
    /// } else if let passData = service.generatedPassData {
    ///     print("Success! Generated \(passData.count) bytes")
    /// }
    /// ```
    @MainActor
    func generateWalletPass(from image: UIImage, for card: Card) async {
        print(card)
        isProcessing = true
        error = nil
        extractedData = nil
        generatedPassData = nil
        processingProgress = 0.0
        
        do {
            // Step 1: Compress and prepare image (10%)
            updateProgress(0.10, status: "Preparing image...")
            guard let imageData = compressImage(image) else {
                throw CardProcessingError.invalidImage
            }
            
            print("📸 Image compressed: \(imageData.count) bytes")
            
            // Step 2: Send to Gemini via server (30%)
            updateProgress(0.30, status: "Analyzing card with AI...")
            let geminiResponse = try await serverApi.analyzeCardWithGemini(imageData: imageData)
            
            print("✅ Gemini analysis complete:")
            print("   Format: \(geminiResponse.passFormat.rawValue)")
            print("   Organization: \(geminiResponse.cardDetails.organizationName ?? "nil")")
            print("   Barcode: \(geminiResponse.cardDetails.barcodeMessage ?? "nil")")
            
            extractedData = geminiResponse
            
            // Step 3: Update card model first so we have the details for design generation (45%)
            updateProgress(0.45, status: "Saving card details...")
            updateCard(card, with: geminiResponse)
            
            // Step 4: Generate design/banner image using the separate design generation endpoint (65%)
            // Always call the design generation endpoint - this is separate from card data extraction
            updateProgress(0.50, status: "Generating card design...")
            
            let designRequest = CardDesignRequest(
                organizationName: card.organizationName.isEmpty ? nil : card.organizationName,
                description: card.passDescription.isEmpty ? nil : card.passDescription,
                logoText: card.logoText,
                backgroundColor: card.backgroundColor,
                foregroundColor: card.foregroundColor,
                designStyle: nil,
                additionalContext: nil
            )
            
            // Design generation is fully non-fatal: try? silently converts any error to nil
            // so the pipeline always continues even if the server returns 500 / quota exceeded
            if let designResponse = try? await serverApi.generateCardDesign(
                cardDetails: designRequest,
                imageData: imageData
            ) {
                updateProgress(0.60, status: "Downloading generated design...")
                let designImageData = try? await downloadDesignImage(from: designResponse.designImage)
                card.bannerImageData = designImageData
                if let bytes = designImageData {
                    print("🎨 Design generated and set as banner: \(bytes.count) bytes")
                } else {
                    print("⚠️ Design downloaded but no image data — banner will use background color")
                }
            } else {
                card.bannerImageData = nil
                print("⚠️ Design generation skipped — banner will use background color")
            }
            
            updateProgress(0.65, status: "Design complete...")
            
            // Step 5: Generate colors if not provided (70%)
            updateProgress(0.70, status: "Analyzing colors...")
            if card.dominantColorsHex.isEmpty {
                let colors = await extractDominantColors(from: image)
                card.dominantColorsHex = colors
            }
            
            // Step 6: Process logo if available (80%)
            updateProgress(0.80, status: "Processing logo...")
            if let logoImage = try await extractLogoFromDesign(image) {
                card.logoImageData = logoImage.pngData()
            }
            
            // Step 7: Generate Pass (95%)
            updateProgress(0.95, status: "Generating wallet pass...")
            let passData = try await passKitIntegrator.generateWalletPassFromGemini(
                for: card,
                with: geminiResponse
            )
            
            updateProgress(1.0, status: "Complete!")
            
            generatedPassData = passData
            card.pkpassData = passData
            card.isDraft = false
            
            print("✅ Pass generation complete!")
            
        } catch let error as ServerApiError {
            await MainActor.run {
                self.error = "Server error: \(error.errorDescription ?? error.localizedDescription)"
                self.processingProgress = 0.0
                self.isProcessing = false
            }
        } catch let error as CardProcessingError {
            await MainActor.run {
                self.error = error.errorDescription
                self.processingProgress = 0.0
                self.isProcessing = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to process card: \(error.localizedDescription)"
                self.processingProgress = 0.0
                self.isProcessing = false
            }
        }
        
        isProcessing = false
    }
    
    // MARK: - Helper Methods (Gemini-Based)
    
    /// Compresses a UIImage to ensure it meets size requirements for network upload.
    ///
    /// This method implements adaptive compression to reduce image file size while maintaining
    /// acceptable quality for AI analysis. It uses a multi-stage approach:
    ///
    /// 1. Initial JPEG compression at 0.8 quality
    /// 2. Progressive quality reduction if size exceeds limit
    /// 3. Image resizing as a last resort if quality reduction is insufficient
    ///
    /// ## Compression Strategy
    ///
    /// The method prioritizes maintaining image dimensions over quality, as spatial relationships
    /// are important for accurate AI analysis. Only when quality reduction to 0.1 still produces
    /// oversized files does it resort to resizing the image proportionally.
    ///
    /// ## Size Limits
    ///
    /// - Maximum file size: 5MB (5,242,880 bytes)
    /// - Minimum quality: 0.1 (10% JPEG quality)
    /// - Compression format: JPEG (balanced quality/size ratio)
    ///
    /// - Parameter image: The UIImage to compress
    /// - Returns: Compressed image data as JPEG, or `nil` if the image cannot be processed
    ///
    /// - Note: The method preserves the original image's aspect ratio during any resizing operations.
    ///
    /// - Complexity: O(n) where n is the number of compression iterations needed
    ///
    /// - Example:
    /// ```swift
    /// if let compressedData = compressImage(largeImage) {
    ///     print("Compressed to \(compressedData.count) bytes")
    /// }
    /// ```
    private func compressImage(_ image: UIImage) -> Data? {
        let maxSizeInBytes = 5 * 1024 * 1024 // 5 MB
        var compressionQuality: CGFloat = 0.8
        
        guard var imageData = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        
        // Reduce quality if image is too large
        while imageData.count > maxSizeInBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            guard let compressedData = image.jpegData(compressionQuality: compressionQuality) else {
                break
            }
            imageData = compressedData
        }
        
        // If still too large, resize the image
        if imageData.count > maxSizeInBytes {
            let ratio = sqrt(CGFloat(maxSizeInBytes) / CGFloat(imageData.count))
            let newSize = CGSize(
                width: image.size.width * ratio,
                height: image.size.height * ratio
            )
            
            if let resizedImage = resizeImage(image, to: newSize) {
                imageData = resizedImage.jpegData(compressionQuality: 0.8) ?? imageData
            }
        }
        
        return imageData
    }
    
    /// Resizes a UIImage to a target size while maintaining quality.
    ///
    /// This method creates a new bitmap context at the specified size and draws the image into it.
    /// The resulting image has a scale of 1.0, making it suitable for network uploads where
    /// actual pixel dimensions matter more than points.
    ///
    /// ## Use Case
    ///
    /// This method is typically called as a last resort when compression quality reduction alone
    /// cannot bring an image under the required file size limit. It's invoked by `compressImage(_:)`
    /// when aggressive quality reduction still produces oversized files.
    ///
    /// - Parameters:
    ///   - image: The UIImage to resize
    ///   - size: The target size in points
    ///
    /// - Returns: A new resized UIImage, or `nil` if the graphics context cannot be created
    ///
    /// - Note: The method uses `UIGraphicsBeginImageContextWithOptions` with opaque=false to preserve
    ///         any transparency in the original image.
    ///
    /// - Important: The returned image always has a scale of 1.0 regardless of the input image's scale.
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Downloads or decodes a banner/strip design image from either a URL or base64-encoded data URI.
    ///
    /// This method handles two different source formats returned by the Gemini design generation API
    /// (from `/api/gemini/cardDesignGenerating` endpoint):
    ///
    /// ## Expected Image Specifications
    ///
    /// The design image should be a strip/banner image for Apple PassKit generic passes:
    /// - **Size**: 1125 x 432 pixels (@3x resolution)
    /// - **Alternative sizes**: 750 x 288 (@2x) or 375 x 144 (@1x)
    /// - **Format**: PNG or JPEG
    /// - **Usage**: Displayed as a horizontal strip below the logo/header section of the pass
    ///
    /// ## Data URI Format
    ///
    /// If the source starts with "data:image", it's treated as a base64-encoded data URI:
    /// ```
    /// data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA...
    /// ```
    /// The method extracts and decodes the base64 portion.
    ///
    /// ## HTTP URL Format
    ///
    /// If the source is a standard HTTP/HTTPS URL, the method downloads the image using URLSession:
    /// ```
    /// https://example.com/generated-design.png
    /// ```
    ///
    /// ## Empty or Invalid Source Handling
    ///
    /// The method gracefully handles various error scenarios:
    /// - Empty string returns `nil` (pass will use background color)
    /// - Invalid URLs return `nil` rather than throwing
    /// - Network errors are caught and logged
    /// - HTTP errors (non-200 status codes) return `nil`
    /// - Invalid or corrupted image data returns `nil`
    ///
    /// This allows the processing pipeline to continue even if design image retrieval fails.
    /// When `nil` is returned, the pass will use the background color for the banner area.
    ///
    /// ## Validation
    ///
    /// After downloading/decoding, the method validates that the data is a valid image
    /// by attempting to create a UIImage. This ensures corrupted data doesn't get saved.
    ///
    /// - Parameter source: Either a data URI string or HTTP(S) URL string from the design generation response
    /// - Returns: The image data if successfully retrieved/decoded and validated, or `nil` on failure
    ///
    /// - Note: This method uses standard URLSession which respects system proxy settings and SSL pinning.
    ///
    /// - Example:
    /// ```swift
    /// // Base64 data URI
    /// let dataUri = "data:image/png;base64,iVBORw0KGgo..."
    /// let imageData = try await downloadDesignImage(from: dataUri)
    ///
    /// // HTTP URL
    /// let urlString = "https://cdn.example.com/design.jpg"
    /// let imageData = try await downloadDesignImage(from: urlString)
    ///
    /// // Empty or missing
    /// let empty = ""
    /// let imageData = try await downloadDesignImage(from: empty) // Returns nil
    /// ```
    private func downloadDesignImage(from source: String) async throws -> Data? {
        // Handle empty source - this is not an error, just means no design image
        guard !source.isEmpty else {
            print("ℹ️ No design image provided - banner will use background color")
            return nil
        }
        
        var imageData: Data? = nil
        
        // Check if it's a base64 data URI (format: "data:image/png;base64,...")
        if source.hasPrefix("data:image") {
            // Extract base64 data after the comma
            if let base64String = source.components(separatedBy: ",").last,
               let decodedData = Data(base64Encoded: base64String) {
                print("📥 Decoded base64 design image: \(decodedData.count) bytes")
                imageData = decodedData
            } else {
                print("⚠️ Failed to decode base64 design image")
                return nil
            }
        } else {
            // Otherwise treat as URL
            guard let url = URL(string: source) else {
                print("⚠️ Invalid design image URL: \(source)")
                return nil
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("⚠️ Failed to download design image: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    return nil
                }
                
                print("📥 Downloaded design image from URL: \(data.count) bytes")
                imageData = data
                
            } catch {
                print("⚠️ Network error downloading design image: \(error.localizedDescription)")
                return nil
            }
        }
        
        // Validate that the data is actually a valid image
        // This prevents corrupted data from being saved to the Card model
        if let data = imageData {
            if let image = UIImage(data: data) {
                let dimensions = "\(Int(image.size.width))x\(Int(image.size.height))"
                let scale = image.scale
                let pixelDimensions = "\(Int(image.size.width * scale))x\(Int(image.size.height * scale))"
                
                print("✅ Valid design image: \(dimensions) pts @ \(scale)x = \(pixelDimensions) pixels")
                
                // Check if dimensions are reasonable for a strip image
                // Expected: 1125x432 (@3x), 750x288 (@2x), or 375x144 (@1x)
                // We'll be lenient and accept anything with an aspect ratio between 2:1 and 3:1
                let aspectRatio = image.size.width / image.size.height
                if aspectRatio < 2.0 || aspectRatio > 3.5 {
                    print("⚠️ Warning: Design image aspect ratio (\(String(format: "%.2f", aspectRatio)):1) is unusual for strip images")
                    print("   Recommended ratio is approximately 2.6:1 (1125x432)")
                }
                
                return data
            } else {
                print("❌ Downloaded data is not a valid image format")
                return nil
            }
        }
        
        return nil
    }
    
    /// Updates a Card model with data extracted from Gemini AI analysis.
    ///
    /// This method maps the structured Gemini response to the Card model's properties,
    /// aligning with Apple PassKit's Generic pass format. It converts Gemini's field
    /// structure into the JSON format expected by the Card model.
    ///
    /// ## Updated Properties
    ///
    /// The method updates the following Card properties:
    ///
    /// - `passTypeIdentifier`: Set to generic pass format
    /// - `organizationName`: Company/organization name from Gemini
    /// - `passDescription`: Card description
    /// - `logoText`: Text to display next to logo
    /// - `barcodeMessage`: The extracted barcode data
    /// - `barcodeFormat`: Mapped to PassKit format constants
    /// - `barcodeMessageEncoding`: Encoding for barcode (default: "iso-8859-1")
    /// - `foregroundColor`: Converted from rgb() to hex format
    /// - `backgroundColor`: Converted from rgb() to hex format
    /// - `labelColor`: Converted from rgb() to hex format
    /// - `primaryFieldsJson`: JSON array of primary fields
    /// - `secondaryFieldsJson`: JSON array of secondary fields
    /// - `auxiliaryFieldsJson`: JSON array of auxiliary fields
    /// - `backFieldsJson`: JSON array of back fields
    /// - `headerFieldsJson`: JSON array of header fields
    /// - `expirationDate`: Expiration date in ISO 8601 format
    /// - `relevantDate`: Relevant date in ISO 8601 format
    ///
    /// ## Color Conversion
    ///
    /// Colors from Gemini can be in rgb() format (e.g., "rgb(245, 197, 67)") or hex format.
    /// This method converts rgb() to hex format for storage.
    ///
    /// ## Field Mapping
    ///
    /// Gemini's GeminiPassField structures are converted to Card's PassField structures
    /// and stored as JSON strings for each field category.
    ///
    /// - Parameters:
    ///   - card: The Card model to update
    ///   - response: The complete Gemini analysis response containing extracted data
    ///
    /// - Note: The method preserves all field metadata including dateStyle, textAlignment, etc.
    ///
    /// - SeeAlso: `mapGeminiBarcodeFormat(_:)`, `convertColorToHex(_:)`
    private func updateCard(_ card: Card, with response: GeminiCardAnalysisResponse) {
        let details = response.cardDetails
        
        // Pass metadata
        card.passTypeIdentifier = "pass.com.example.generic"
        card.formatVersion = 1
        
        // Organization and description
        if let orgName = details.organizationName {
            card.organizationName = orgName
        }
        
        if let description = details.description {
            card.passDescription = description
        }
        
        if let logoText = details.logoText {
            card.logoText = logoText
        }
        
        // Barcode information
        if let barcodeMessage = details.barcodeMessage {
            card.barcodeMessage = barcodeMessage
        }
        
        if let barcodeFormat = details.barcodeFormat {
            card.barcodeFormat = mapGeminiBarcodeFormat(barcodeFormat)
        }
        
        if let encoding = details.barcodeMessageEncoding {
            card.barcodeMessageEncoding = encoding
        }
        
        // Colors - convert from rgb() to hex format
        if let bgColor = details.backgroundColor {
            card.backgroundColor = convertColorToHex(bgColor)
            // Also add to dominantColorsHex for UI purposes
            if !card.dominantColorsHex.contains(card.backgroundColor) {
                card.dominantColorsHex.append(card.backgroundColor)
            }
        }
        
        if let fgColor = details.foregroundColor {
            card.foregroundColor = convertColorToHex(fgColor)
            // Also add to dominantColorsHex for UI purposes
            if !card.dominantColorsHex.contains(card.foregroundColor) {
                card.dominantColorsHex.append(card.foregroundColor)
            }
        }
        
        if let labelColor = details.labelColor {
            card.labelColor = convertColorToHex(labelColor)
        }
        
        // Convert GeminiPassField arrays to PassField arrays and store as JSON
        if let headerFields = details.headerFields {
            card.updateHeaderFields(convertGeminiFieldsToPassFields(headerFields))
        }
        
        if let primaryFields = details.primaryFields {
            card.updatePrimaryFields(convertGeminiFieldsToPassFields(primaryFields))
        }
        
        if let secondaryFields = details.secondaryFields {
            card.updateSecondaryFields(convertGeminiFieldsToPassFields(secondaryFields))
        }
        
        if let auxiliaryFields = details.auxiliaryFields {
            card.updateAuxiliaryFields(convertGeminiFieldsToPassFields(auxiliaryFields))
        }
        
        if let backFields = details.backFields {
            card.updateBackFields(convertGeminiFieldsToPassFields(backFields))
        }
        
        // Dates
        if let expirationDate = details.expirationDate {
            card.expirationDate = expirationDate
        }
        
        if let relevantDate = details.relevantDate {
            card.relevantDate = relevantDate
        }
        
        print("📝 Card updated with Gemini data (PassKit Generic format)")
    }
    
    /// Converts Gemini's field structure to Card's PassField structure
    private func convertGeminiFieldsToPassFields(_ geminiFields: [GeminiPassField]) -> [PassField] {
        return geminiFields.map { geminiField in
            var passField = PassField(
                key: geminiField.key,
                label: geminiField.label,
                value: geminiField.value,
                textAlignment: geminiField.textAlignment
            )
            
            // Copy additional properties
            passField.dateStyle = geminiField.dateStyle
            passField.timeStyle = geminiField.timeStyle
            passField.numberStyle = geminiField.numberStyle
            passField.currencyCode = geminiField.currencyCode
            passField.changeMessage = geminiField.changeMessage
            
            return passField
        }
    }
    
    /// Converts color from rgb() format or hex to clean hex format
    /// Examples:
    /// - "rgb(245, 197, 67)" -> "#F5C543"
    /// - "#F5C543" -> "#F5C543"
    /// - "F5C543" -> "#F5C543"
    private func convertColorToHex(_ color: String) -> String {
        // If already in hex format, ensure it has # prefix
        if color.hasPrefix("#") {
            return color
        }
        
        // If no # but looks like hex (6 or 8 characters), add #
        if !color.contains("rgb") && (color.count == 6 || color.count == 8) {
            return "#" + color
        }
        
        // Parse rgb() format
        if color.hasPrefix("rgb") {
            // Extract numbers from rgb(r, g, b) or rgba(r, g, b, a)
            let numbers = color
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: " ", with: "")
                .split(separator: ",")
                .compactMap { Int($0) }
            
            if numbers.count >= 3 {
                let r = numbers[0]
                let g = numbers[1]
                let b = numbers[2]
                return String(format: "#%02X%02X%02X", r, g, b)
            }
        }
        
        // Fallback - return as is
        return color
    }
    
    /// Maps Gemini's barcode format strings to Apple PassKit barcode format constants.
    ///
    /// Gemini AI returns barcode formats as human-readable strings like "QR Code",
    /// "PDF417", "Code 128", etc. This method converts them to the exact string constants
    /// expected by Apple's PassKit framework.
    ///
    /// ## Supported Formats
    ///
    /// The method recognizes and maps the following formats:
    ///
    /// - **QR Code** → `PKBarcodeFormatQR`
    /// - **PDF417** → `PKBarcodeFormatPDF417`
    /// - **Aztec** → `PKBarcodeFormatAztec`
    /// - **Code 128** → `PKBarcodeFormatCode128`
    ///
    /// ## Matching Strategy
    ///
    /// The method uses case-insensitive substring matching, making it robust against
    /// variations in formatting:
    /// - "QR", "qr code", "QR Code" all map to `PKBarcodeFormatQR`
    /// - "PDF-417", "pdf417", "PDF 417" all map to `PKBarcodeFormatPDF417`
    ///
    /// ## Default Behavior
    ///
    /// If the format string doesn't match any known format, the method returns
    /// `PKBarcodeFormatQR` as a safe default, since QR codes are the most common
    /// and widely supported barcode format.
    ///
    /// - Parameter format: The barcode format string from Gemini (e.g., "QR Code", "PDF417")
    /// - Returns: The corresponding PassKit format constant string
    ///
    /// - Note: The PassKit constants are strings, not enum cases, as they're used in
    ///         pass.json generation for the .pkpass file.
    ///
    /// - Example:
    /// ```swift
    /// let format1 = mapGeminiBarcodeFormat("QR Code")      // "PKBarcodeFormatQR"
    /// let format2 = mapGeminiBarcodeFormat("pdf417")       // "PKBarcodeFormatPDF417"
    /// let format3 = mapGeminiBarcodeFormat("unknown")      // "PKBarcodeFormatQR" (default)
    /// ```
    private func mapGeminiBarcodeFormat(_ format: String) -> String {
        let lowercased = format.lowercased()
        
        if lowercased.contains("qr") {
            return "PKBarcodeFormatQR"
        } else if lowercased.contains("pdf417") {
            return "PKBarcodeFormatPDF417"
        } else if lowercased.contains("aztec") {
            return "PKBarcodeFormatAztec"
        } else if lowercased.contains("code128") {
            return "PKBarcodeFormatCode128"
        } else {
            return "PKBarcodeFormatQR" // Default
        }
    }
    
    /// Extracts the logo region from a card image using a simple crop heuristic.
    ///
    /// This method attempts to isolate the logo from a card image by cropping a region where
    /// logos are typically positioned. It uses common card design conventions where logos
    /// appear in the top-left area of the card.
    ///
    /// ## Extraction Strategy
    ///
    /// The method uses a heuristic-based approach:
    ///
    /// 1. **Region Selection**: Crops the top 30% and left 40% of the card image
    /// 2. **Resizing**: Scales the cropped region to standard logo dimensions (320x320)
    /// 3. **Format**: Returns as UIImage for further processing or storage
    ///
    /// ## Logo Region Dimensions
    ///
    /// - Horizontal extent: 40% of card width (left-aligned)
    /// - Vertical extent: 30% of card height (top-aligned)
    /// - Final size: 320x320 points (@2x retina resolution)
    ///
    /// ## Limitations
    ///
    /// This is a simple spatial heuristic and may not work perfectly for all card designs:
    /// - Centered logos may be only partially captured
    /// - Right-aligned logos will be missed
    /// - Bottom-aligned logos will not be detected
    ///
    /// For production use, consider enhancing with:
    /// - Machine learning-based logo detection
    /// - Saliency analysis to find prominent regions
    /// - Color clustering to identify distinct logo areas
    ///
    /// - Parameter image: The full card image to extract the logo from
    /// - Returns: A resized UIImage containing the extracted logo region, or `nil` if extraction fails
    ///
    /// - Note: The method returns `nil` if the image cannot be converted to CGImage or if
    ///         cropping fails. This is a non-fatal error that allows processing to continue.
    ///
    /// - Example:
    /// ```swift
    /// if let logo = try await extractLogoFromDesign(cardImage) {
    ///     card.logoImageData = logo.pngData()
    /// }
    /// ```
    private func extractLogoFromDesign(_ image: UIImage) async throws -> UIImage? {
        // Simple approach: crop top-left corner where logos typically are
        guard let cgImage = image.cgImage else { return nil }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Logo is typically in top 30% and left 40% of card
        let logoWidth = imageWidth * 0.4
        let logoHeight = imageHeight * 0.3
        
        let cropRect = CGRect(x: 0, y: 0, width: logoWidth, height: logoHeight)
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        let logoImage = UIImage(cgImage: croppedCGImage)
        
        // Resize to standard logo size (160x160 @1x, 320x320 @2x)
        return resizeImage(logoImage, to: CGSize(width: 320, height: 320))
    }
    
    /// Extracts the dominant colors from an image for use in pass design.
    ///
    /// This method analyzes an image to identify the most prominent colors, which are then
    /// used to style the Apple Wallet pass for a cohesive visual experience. The analysis
    /// is performed on a background thread to avoid blocking the main thread.
    ///
    /// ## Algorithm
    ///
    /// The color extraction process:
    ///
    /// 1. **Downsampling**: Resizes image to 100x100 for efficient analysis
    /// 2. **Sampling**: Examines every 20th pixel to reduce computation
    /// 3. **Counting**: Builds a histogram of color frequencies
    /// 4. **Ranking**: Sorts colors by frequency to find dominant ones
    /// 5. **Selection**: Returns top 3 most common colors
    ///
    /// ## Color Representation
    ///
    /// Colors are returned as hexadecimal strings (e.g., "#FF5733") for easy
    /// storage and serialization. The format is compatible with web standards
    /// and can be easily converted to SwiftUI/UIKit colors.
    ///
    /// ## Thread Safety
    ///
    /// The method uses Swift Concurrency with `withCheckedContinuation` to safely
    /// bridge the Core Graphics work (performed on a background queue) with async/await.
    /// This ensures the main thread remains responsive during analysis.
    ///
    /// ## Fallback Behavior
    ///
    /// If color extraction fails at any point (invalid image, no context, etc.),
    /// the method returns a default blue color: `["#3B82F6"]`
    ///
    /// - Parameter image: The card image to analyze
    /// - Returns: An array of 1-3 hex color strings, sorted by frequency (most common first)
    ///
    /// - Note: Alpha channel is considered - pixels with alpha < 128 are excluded from analysis
    ///
    /// - Complexity: O(n) where n is the number of pixels sampled (approximately 500 for a 100x100 image)
    ///
    /// - SeeAlso: `performColorExtraction(from:)` for the actual analysis implementation
    private func extractDominantColors(from image: UIImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: ["#3B82F6"])
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let colors = self.performColorExtraction(from: cgImage)
                continuation.resume(returning: colors)
            }
        }
    }
    
    /// Performs the actual color extraction analysis on a background thread.
    ///
    /// This method does the heavy lifting of color analysis using Core Graphics. It creates
    /// a bitmap context, draws the image into it, and analyzes the raw pixel data to determine
    /// the most frequent colors.
    ///
    /// ## Processing Steps
    ///
    /// 1. **Context Creation**: Creates a 100x100 RGBA bitmap context
    /// 2. **Rendering**: Draws the CGImage into the context (downsampling if needed)
    /// 3. **Pixel Access**: Binds the raw buffer to access individual color values
    /// 4. **Sampling**: Examines every 20th pixel (stride of 20) for efficiency
    /// 5. **Filtering**: Excludes nearly-transparent pixels (alpha < 128)
    /// 6. **Histogram**: Counts occurrences of each unique color
    /// 7. **Sorting**: Ranks colors by frequency
    /// 8. **Selection**: Returns top 3 colors
    ///
    /// ## Color Format
    ///
    /// Colors are converted to uppercase hex strings: "#RRGGBB"
    /// - Red: bytes 0, 4, 8, 12, ... (stride 4)
    /// - Green: bytes 1, 5, 9, 13, ...
    /// - Blue: bytes 2, 6, 10, 14, ...
    /// - Alpha: bytes 3, 7, 11, 15, ...
    ///
    /// ## Performance
    ///
    /// - Image size: 100x100 = 10,000 pixels
    /// - Sampling rate: Every 20th pixel = ~500 samples
    /// - Memory: ~40KB for bitmap context
    ///
    /// ## Error Resilience
    ///
    /// The method returns a default blue color if any step fails:
    /// - Context creation failure
    /// - Image drawing failure
    /// - Invalid pixel data
    /// - No valid colors found
    ///
    /// - Parameter cgImage: The Core Graphics image to analyze
    /// - Returns: Array of 1-3 hex color strings, or `["#3B82F6"]` on failure
    ///
    /// - Important: This method performs substantial computation and should only be
    ///              called from background threads or within async contexts.
    ///
    /// - Note: The color counting uses a dictionary with hex strings as keys, which
    ///         means very similar colors are treated as distinct. Consider implementing
    ///         color bucketing for more robust results.
    private func performColorExtraction(from cgImage: CGImage) -> [String] {
        let width = 100
        let height = 100
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ["#3B82F6"]
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return ["#3B82F6"]
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var colorCounts: [String: Int] = [:]
        
        let totalPixels = width * height * 4
        
        for i in stride(from: 0, to: totalPixels, by: 20) {
            guard i + 3 < totalPixels else { continue }
            
            let r = buffer[i]
            let g = buffer[i + 1]
            let b = buffer[i + 2]
            let a = buffer[i + 3]
            
            guard a > 128 else { continue }
            
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            colorCounts[hex, default: 0] += 1
        }
        
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let topColors = Array(sortedColors.prefix(3).map { $0.key })
        
        return topColors.isEmpty ? ["#3B82F6"] : topColors
    }
    
    /// Updates the processing progress and status message on the main thread.
    ///
    /// This helper method ensures thread-safe updates to the observable progress properties.
    /// It's called throughout the processing pipeline to keep the UI informed of the current
    /// status and progress percentage.
    ///
    /// ## Main Actor Isolation
    ///
    /// The method explicitly uses `@MainActor.run` to ensure all property updates occur on
    /// the main thread, making them safe for SwiftUI observation and preventing potential
    /// data races.
    ///
    /// ## Logging
    ///
    /// Each progress update is also logged to the console for debugging purposes, showing
    /// both the percentage complete and the status message.
    ///
    /// - Parameters:
    ///   - progress: The current progress value from 0.0 (0%) to 1.0 (100%)
    ///   - status: A human-readable description of the current operation
    ///
    /// - Note: The method creates a detached Task to perform the update asynchronously,
    ///         allowing the calling code to continue without waiting.
    ///
    /// - Example:
    /// ```swift
    /// updateProgress(0.30, status: "Analyzing card with AI...")
    /// // Console: Processing: 30% - Analyzing card with AI...
    /// // Updates: processingProgress = 0.30, processingStatus = "Analyzing card with AI..."
    /// ```
    private func updateProgress(_ progress: Double, status: String) {
        Task { @MainActor in
            self.processingProgress = progress
            self.processingStatus = status
            print("Processing: \(Int(progress * 100))% - \(status)")
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during card image processing.
///
/// This enumeration defines the specific error cases that may arise during the card processing
/// pipeline, from initial image validation through final pass generation. Each case includes
/// a user-friendly error message accessible via the `errorDescription` property.
///
/// ## Error Cases
///
/// - `invalidImage`: The provided image is corrupted, unreadable, or in an unsupported format
/// - `noTextFound`: AI analysis completed but couldn't extract any readable text from the card
/// - `processingFailed`: A general processing error occurred during one of the pipeline steps
/// - `networkError`: Network connectivity issues prevented communication with the server
///
/// ## Usage in Error Handling
///
/// These errors are caught in the main processing method and converted to user-friendly
/// messages for display:
///
/// ```swift
/// do {
///     try await processCard()
/// } catch let error as CardProcessingError {
///     self.error = error.errorDescription
/// }
/// ```
///
/// ## Conformance
///
/// Conforms to `LocalizedError` to provide localized, user-facing error descriptions.
///
/// - SeeAlso: `CardProcessingService.generateWalletPass(from:for:)`
enum CardProcessingError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image is invalid"
        case .noTextFound:
            return "No text was found in the image"
        case .processingFailed:
            return "Failed to process the card"
        case .networkError:
            return "Network connection failed"
        }
    }
}
