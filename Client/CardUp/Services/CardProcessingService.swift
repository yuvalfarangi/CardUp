//
//  CardProcessingService.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import UIKit
import SwiftUI
import Vision
import FoundationModels
import CoreGraphics
import CoreImage

// MARK: - Hebrew Detection Extension (inlined)
private extension String {
    var containsHebrewCharacters: Bool {
        // Hebrew Unicode range: U+0590 to U+05FF
        let hebrewRange = "\u{0590}"..."\u{05FF}"
        return self.unicodeScalars.contains { scalar in
            hebrewRange.contains(String(scalar))
        }
    }
}

@Observable
final class CardProcessingService {
    var isProcessing: Bool = false
    var extractedData: ExtractedCardData?
    var generatedPassData: Data?
    var error: String?
    var processingProgress: Double = 0.0
    
    private let passKitIntegrator = PassKitIntegrator()
    private let cloudFlareIntegrator = CloudFlareIntegrator()
    private let languageModel = SystemLanguageModel.default
    
    // MARK: - Main Processing Pipeline
    
    @MainActor
    func generateWalletPass(from image: UIImage, for card: Card) async {
        isProcessing = true
        error = nil
        extractedData = nil
        generatedPassData = nil
        processingProgress = 0.0
        
        do {
            // Step 1: Extract Text first (15%)
            updateProgress(0.15, status: "Extracting text...")
            let extractedText = try await fetchText(from: image)
            
            print("📊 Text extraction summary:")
            print("   Length: \(extractedText.count) characters")
            
            guard !extractedText.isEmpty else {
                throw CardProcessingError.noTextFound
            }
            
            // Step 2: Determine Pass Type (25%)
            updateProgress(0.25, status: "Analyzing card type...")
            let passType = try await generateCardType(image: image)
            card.passType = passType
            
            // Step 3: Process Text with AI (45%)
            updateProgress(0.45, status: "Processing with Apple Intelligence...")
            let processedData = try await processTextWithFoundationModels(text: extractedText, image: image)
            
            // Step 4: Extract Colors (60%)
            updateProgress(0.6, status: "Analyzing colors...")
            let dominantColors = try await fetchColors(from: image)
            card.dominantColorsHex = dominantColors
            
            // Step 5: Get Logo (75%)
            updateProgress(0.75, status: "Extracting logo...")
            let logoData = try await getLogo(from: image, companyName: processedData.companyName)
            card.logoImageData = logoData
            
            // Step 6: Generate Graphics (88%)
            updateProgress(0.88, status: "Creating graphics...")
            let bannerData = try await createGraphic(from: image, extractedData: processedData)
            card.bannerImageData = bannerData
            
            // Step 7: Generate Final Pass (100%)
            updateProgress(0.95, status: "Generating wallet pass...")
            
            // Save extracted data to card BEFORE generating pass
            card.barcodeString = processedData.barcodeString ?? ""
            card.barcodeFormat = processedData.barcodeFormat ?? "Code128"
            
            let cardData = processedData.toCardData()
            let jsonData = try JSONEncoder().encode(cardData)
            card.extractedTextJson = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Debug: Print extracted data
            print("📝 Extracted Data:")
            print("   Card Name: \(processedData.cardName ?? "nil")")
            print("   Company Name: \(processedData.companyName ?? "nil")")
            print("   Membership: \(processedData.membershipNumber ?? "nil")")
            print("   Barcode: \(processedData.barcodeString ?? "nil")")
            print("   Colors: \(dominantColors)")
            
            // Generate the final pass
            let passData = try await passKitIntegrator.generateWalletPass(for: card, with: processedData)
            
            updateProgress(1.0, status: "Complete!")
            
            extractedData = processedData
            generatedPassData = passData
            
        } catch {
            await MainActor.run {
                self.error = "Failed to process card: \(error.localizedDescription)"
                self.processingProgress = 0.0
            }
        }
        
        isProcessing = false
    }
    
    // MARK: - Individual Processing Functions
    
    private func generateCardType(image: UIImage) async throws -> String {
        // Simplified approach - use text analysis without Foundation Models to avoid hanging
        // Foundation Models image analysis isn't directly supported yet
        return "storeCard" // Default to storeCard for all loyalty cards
    }
    
    private func fetchText(from image: UIImage) async throws -> String {
        // Preprocess image for better OCR
        let preprocessedImage = preprocessImageForOCR(image)
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = preprocessedImage.cgImage else {
                continuation.resume(throwing: CardProcessingError.invalidImage)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: CardProcessingError.noTextFound)
                    return
                }
                
                print("📸 Vision returned \(observations.count) text observations")
                
                // Get the recognized text
                let recognizedStrings = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                
                print("📖 Recognized text with \(observations.count) observations:")
                print("   Total text length: \(fullText.count) characters")
                
                print("   First 15 lines:")
                recognizedStrings.prefix(15).forEach { line in
                    print("   \(line)")
                }
                
                continuation.resume(returning: fullText)
            }
            
            // Vision OCR Configuration
            request.recognitionLanguages = ["en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.001
            request.revision = VNRecognizeTextRequestRevision3
            request.customWords = []
            
            // Request handler with orientation correction
            let options: [VNImageOption: Any] = [
                .ciContext: CIContext(options: nil)
            ]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: options)
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Image Preprocessing
    
    /// Preprocesses image to improve OCR accuracy for Hebrew text
    private func preprocessImageForOCR(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: nil)
        
        // Apply filters to enhance text readability
        var processedImage = ciImage
        
        // 1. Auto-enhance (contrast, exposure)
        if let autoEnhance = CIFilter(name: "CIColorControls") {
            autoEnhance.setValue(processedImage, forKey: kCIInputImageKey)
            autoEnhance.setValue(1.2, forKey: kCIInputContrastKey)     // Increase contrast
            autoEnhance.setValue(0.1, forKey: kCIInputBrightnessKey)   // Slightly brighten
            autoEnhance.setValue(1.1, forKey: kCIInputSaturationKey)   // Slight saturation boost
            
            if let output = autoEnhance.outputImage {
                processedImage = output
            }
        }
        
        // 2. Sharpen for clearer text edges
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(processedImage, forKey: kCIInputImageKey)
            sharpen.setValue(0.7, forKey: kCIInputSharpnessKey)
            
            if let output = sharpen.outputImage {
                processedImage = output
            }
        }
        
        // 3. Convert back to UIImage
        if let outputCGImage = context.createCGImage(processedImage, from: processedImage.extent) {
            print("📸 Image preprocessed for better OCR")
            return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        print("⚠️ Image preprocessing failed, using original")
        return image
    }
    
    // Multi-pass recognition for challenging Hebrew text
    // This method uses multiple strategies to maximize Hebrew text detection
    private func fetchTextMultiPass(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw CardProcessingError.invalidImage
        }
        
        print("🔄 Starting HEBREW MULTI-PASS recognition...")
        
        // Pass 1: Accurate mode with full Hebrew support
        print("   Pass 1: Accurate recognition...")
        let pass1Text = try await performTextRecognition(
            on: cgImage,
            languages: ["he", "he-IL", "en-US"],
            pass: 1,
            level: .accurate
        )
        
        // Pass 2: Fast mode (sometimes catches text accurate mode misses)
        print("   Pass 2: Fast recognition...")
        let pass2Text = try await performTextRecognition(
            on: cgImage,
            languages: ["he", "he-IL", "en-US"],
            pass: 2,
            level: .fast
        )
        
        // Pass 3: Hebrew-only mode with auto-detection
        print("   Pass 3: Hebrew-focused...")
        let pass3Text = try await performTextRecognition(
            on: cgImage,
            languages: ["he", "he-IL"],
            pass: 3,
            level: .accurate,
            autoDetect: true
        )
        
        // Combine and deduplicate all results
        let allLines = (pass1Text + "\n" + pass2Text + "\n" + pass3Text)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        // Remove duplicates while preserving Hebrew text
        var uniqueLines: [String] = []
        var seenLines = Set<String>()
        
        for line in allLines {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenLines.contains(normalized) && normalized.count > 1 {
                uniqueLines.append(normalized)
                seenLines.insert(normalized)
            }
        }
        
        let finalText = uniqueLines.joined(separator: "\n")
        
        print("✅ Multi-pass complete!")
        print("   Total unique lines: \(uniqueLines.count)")
        print("   Total characters: \(finalText.count)")
        
        return finalText
    }
    
    private func performTextRecognition(
        on cgImage: CGImage,
        languages: [String],
        pass: Int,
        level: VNRequestTextRecognitionLevel = .accurate,
        autoDetect: Bool = false
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("   ❌ Pass \(pass) failed: \(error)")
                    continuation.resume(returning: "")
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Get the recognized text from observations
                let recognizedStrings = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }
                
                let text = recognizedStrings.joined(separator: "\n")
                
                print("   ✓ Pass \(pass): \(observations.count) observations, \(text.count) chars")
                
                continuation.resume(returning: text)
            }
            
            // Configure the request
            request.recognitionLanguages = languages
            request.recognitionLevel = level
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = autoDetect
            request.minimumTextHeight = 0.003
            request.revision = VNRecognizeTextRequestRevision3
            request.customWords = []
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("   ❌ Pass \(pass) error: \(error)")
                    continuation.resume(returning: "")
                }
            }
        }
    }
    
    private func processTextWithFoundationModels(text: String, image: UIImage) async throws -> ExtractedCardData {
        guard languageModel.availability == .available else {
            // Fallback to simple pattern matching
            return try await processTextFallback(text: text)
        }
        
        let session = LanguageModelSession(
            instructions: """
            You are an expert at extracting structured data from loyalty card text.
            
            Parse the provided text to extract:
            - Card name (the name of the loyalty program or card)
            - Company name (the business or organization)
            - Barcode string (any numbers that could be barcodes - look for long numeric strings)
            - Barcode format (default to Code128 for numeric strings, QR for mixed content)
            - Membership number (member ID, customer number, account number, etc.)
            - Expiration date (if mentioned, in format MM/YY or MM/YYYY or DD/MM/YY)
            - Logo description (describe the brand based on text)
            - Graphic description (describe the overall style)
            - Additional text (any other relevant text fields)
            
            CRITICAL RULES:
            1. Preserve text in its original language
            2. Numbers are always numeric digits (0-9)
            3. Barcode numbers are typically 8-13 digits long
            4. Member numbers can be shorter (6-10 digits)
            5. Return structured JSON data
            6. Only include information you're confident about
            
            Return accurate structured data.
            """
        )
        
        let prompt = """
        Extract card information from this text:
        
        \(text)
        """
        
        do {
            let response = try await session.respond(to: prompt, generating: ExtractedCardData.self)
            
            // Validate and log the extracted data
            print("✅ Foundation Models extraction complete:")
            print("   Card Name: \(response.content.cardName ?? "nil")")
            print("   Company: \(response.content.companyName ?? "nil")")
            print("   Membership: \(response.content.membershipNumber ?? "nil")")
            print("   Barcode: \(response.content.barcodeString ?? "nil")")
            print("   Expiration: \(response.content.expirationDate ?? "nil")")
            
            return response.content
        } catch {
            print("❌ Foundation Models processing failed: \(error)")
            print("   Falling back to pattern matching...")
            return try await processTextFallback(text: text)
        }
    }
    
    private func processTextFallback(text: String) async throws -> ExtractedCardData {
        // Advanced pattern matching fallback with comprehensive Hebrew support
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var cardName: String?
        var companyName: String?
        var barcodeString: String?
        var membershipNumber: String?
        var expirationDate: String?
        var additionalText: [String] = []
        
        let isHebrewText = text.containsHebrewCharacters
        
        // Count Hebrew characters per line for prioritization
        let linesWithHebrewScore = lines.map { line -> (line: String, hebrewCount: Int, hasNumbers: Bool) in
            let hebrewCount = line.unicodeScalars.filter { scalar in
                let hebrewRange = "\u{0590}"..."\u{05FF}"
                return hebrewRange.contains(String(scalar))
            }.count
            let hasNumbers = line.contains(where: \.isNumber)
            return (line, hebrewCount, hasNumbers)
        }
        
        print("🔍 ENHANCED HEBREW FALLBACK processing:")
        print("   Total lines: \(lines.count)")
        print("   Hebrew detected: \(isHebrewText)")
        print("   Line analysis:")
        linesWithHebrewScore.prefix(10).forEach { item in
            let marker = item.hebrewCount > 0 ? "🇮🇱" : "🇺🇸"
            let nums = item.hasNumbers ? "🔢" : "  "
            print("   \(marker)\(nums) [\(item.hebrewCount) Hebrew] \(item.line)")
        }
        
        // COMPREHENSIVE Hebrew keywords (expanded list)
        let hebrewCardKeywords = [
            "כרטיס", "כרטיס מועדון", "מועדון", "לקוח", "חבר", "כרטיס חבר",
            "כרטיס לקוח", "כרטיס אשראי", "כרטיס חיוב"
        ]
        let hebrewMemberKeywords = [
            "מספר", "מספר חבר", "מספר לקוח", "חבר", "לקוח", "מס'", "מס׳",
            "ת.ז", "ת.ז.", "טלפון", "נייד", "שם"
        ]
        let hebrewExpiryKeywords = [
            "תוקף", "פג תוקף", "בתוקף עד", "תוקף עד", "תאריך תפוגה",
            "עד", "בתוקף"
        ]
        let hebrewCompanyNames = [
            "סופר-פארם", "Super-Pharm", "פוקס", "Fox", "קסטרו", "Castro",
            "גולף", "Golf", "רשת", "ויקטורי", "Victory", "שופרסל", "Shufersal"
        ]
        
        // English keywords for mixed cards
        let englishCardKeywords = [
            "card", "loyalty", "member", "club", "reward", "vip",
            "privilege", "customer"
        ]
        let englishMemberKeywords = [
            "member", "number", "id", "customer", "account", "#", "no."
        ]
        
        // First pass: Find company name (prioritize Hebrew if present)
        if isHebrewText {
            // For Hebrew cards, look for:
            // 1. Known company names
            // 2. Lines with most Hebrew characters (not mixed with numbers)
            // 3. Lines at the top of the card
            
            for (index, item) in linesWithHebrewScore.enumerated() {
                // Skip pure number lines
                if item.line.filter({ $0.isLetter }).count < 3 { continue }
                
                // Check for known Hebrew companies
                let matchesKnownCompany = hebrewCompanyNames.contains { item.line.contains($0) }
                if matchesKnownCompany && companyName == nil {
                    companyName = item.line
                    cardName = "כרטיס מועדון \(item.line)"
                    print("   ✓ Found known company: \(item.line)")
                    break
                }
                
                // First line with substantial Hebrew text (5+ chars) and few numbers
                if item.hebrewCount >= 5 && !item.hasNumbers && companyName == nil && index < 5 {
                    companyName = item.line
                    cardName = "כרטיס מועדון \(item.line)"
                    print("   ✓ Using Hebrew company name: \(item.line)")
                    break
                }
            }
        }
        
        // Fallback to English/mixed text
        if companyName == nil {
            for (index, line) in lines.enumerated() {
                // Skip if too short or all numbers
                if line.count < 3 || line.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                    continue
                }
                
                // Check for English card keywords
                let lowercased = line.lowercased()
                let hasCardKeyword = englishCardKeywords.contains { lowercased.contains($0) }
                
                // First substantial text line is likely the company
                if !hasCardKeyword && line.contains(where: \.isLetter) && index < 5 {
                    companyName = line
                    cardName = "\(line) Loyalty Card"
                    print("   ✓ Using English company name: \(line)")
                    break
                }
            }
        }
        
        // Second pass: Find numbers (barcodes, membership, dates)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract just the digits
            let digits = trimmed.filter { $0.isNumber }
            
            // Long numeric strings (8-13 digits) = barcode
            if digits.count >= 8 && digits.count <= 13 {
                if barcodeString == nil {
                    barcodeString = digits
                    print("   ✓ Found barcode: \(digits)")
                }
                if membershipNumber == nil && digits.count >= 8 {
                    membershipNumber = digits
                    print("   ✓ Found membership number: \(digits)")
                }
                continue
            }
            
            // Medium numeric strings (6-10 digits) = potential member number
            if digits.count >= 6 && digits.count < 8 && membershipNumber == nil {
                membershipNumber = digits
                print("   ✓ Found member number: \(digits)")
                continue
            }
            
            // Date patterns (MM/YY, DD/MM/YY, etc.)
            if trimmed.contains("/") && trimmed.count <= 10 && expirationDate == nil {
                let components = trimmed.components(separatedBy: "/")
                if components.count >= 2 && components.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
                    expirationDate = trimmed
                    print("   ✓ Found expiration date: \(trimmed)")
                    continue
                }
            }
            
            // Check for keyword-based fields
            let lowercased = trimmed.lowercased()
            
            // Hebrew member/expiry keywords
            if isHebrewText {
                let hasHebrewMemberKeyword = hebrewMemberKeywords.contains { trimmed.contains($0) }
                let hasHebrewExpiryKeyword = hebrewExpiryKeywords.contains { trimmed.contains($0) }
                
                if hasHebrewMemberKeyword || hasHebrewExpiryKeyword {
                    if additionalText.count < 3 {
                        additionalText.append(trimmed)
                        print("   ✓ Found keyword line: \(trimmed)")
                    }
                    continue
                }
                
                // Hebrew card type keywords
                let hasCardKeyword = hebrewCardKeywords.contains { trimmed.contains($0) }
                if hasCardKeyword && cardName == nil {
                    cardName = trimmed
                    continue
                }
            }
            
            // English keywords
            let hasEnglishMemberKeyword = englishMemberKeywords.contains { lowercased.contains($0) }
            let hasEnglishCardKeyword = englishCardKeywords.contains { lowercased.contains($0) }
            
            if hasEnglishMemberKeyword || lowercased.contains("exp") || lowercased.contains("valid") {
                if additionalText.count < 3 {
                    additionalText.append(trimmed)
                    print("   ✓ Found keyword line: \(trimmed)")
                }
                continue
            }
            
            if hasEnglishCardKeyword && cardName == nil {
                cardName = trimmed
                continue
            }
            
            // Store other substantial lines as additional text
            if trimmed.count > 2 && additionalText.count < 3 {
                additionalText.append(trimmed)
            }
        }
        
        // Apply sensible defaults
        if companyName == nil {
            companyName = lines.first { $0.count > 2 && !$0.allSatisfy(\.isNumber) } ?? "Unknown Company"
        }
        
        if cardName == nil {
            if let company = companyName {
                cardName = "\(company) Card"
            } else {
                cardName = "Loyalty Card"
            }
        }
        
        // If we have no barcode but have a membership number, use it as barcode too
        if barcodeString == nil && membershipNumber != nil {
            barcodeString = membershipNumber
        }
        
        let result = ExtractedCardData(
            cardName: cardName,
            companyName: companyName,
            barcodeString: barcodeString,
            barcodeFormat: "Code128",
            logoDescription: nil,
            graphicDescription: nil,
            expirationDate: expirationDate,
            membershipNumber: membershipNumber,
            additionalText: additionalText.isEmpty ? nil : additionalText
        )
        
        print("✅ Fallback extraction complete:")
        print("   Card Name: \(result.cardName ?? "nil")")
        print("   Company: \(result.companyName ?? "nil")")
        print("   Membership: \(result.membershipNumber ?? "nil")")
        print("   Barcode: \(result.barcodeString ?? "nil")")
        print("   Expiration: \(result.expirationDate ?? "nil")")
        print("   Additional fields: \(result.additionalText?.count ?? 0)")
        
        return result
    }
    
    private func fetchColors(from image: UIImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: CardProcessingError.invalidImage)
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let colors = self.extractDominantColors(from: cgImage)
                continuation.resume(returning: colors)
            }
        }
    }
    
    private func extractDominantColors(from cgImage: CGImage) -> [String] {
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
            return ["#3B82F6"] // Default blue
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return ["#3B82F6"]
        }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var colorCounts: [String: Int] = [:]
        
        let totalPixels = width * height * 4
        
        // Sample pixels and count color frequencies
        for i in stride(from: 0, to: totalPixels, by: 20) {
            // Ensure we don't read beyond buffer bounds
            guard i + 3 < totalPixels else { continue }
            
            let r = buffer[i]
            let g = buffer[i + 1]
            let b = buffer[i + 2]
            let a = buffer[i + 3]
            
            // Skip transparent pixels
            guard a > 128 else { continue }
            
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            colorCounts[hex, default: 0] += 1
        }
        
        // Return top 3 colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let topColors = Array(sortedColors.prefix(3).map { $0.key })
        
        // Always return at least one color
        return topColors.isEmpty ? ["#3B82F6"] : topColors
    }
    
    private func getLogo(from image: UIImage, companyName: String?) async throws -> Data? {
        // First try to extract logo from the image using Vision
        if let logoImage = try await extractLogoFromImage(image) {
            // Resize and optimize the logo for Apple Wallet
            // Logo size for passes: 160x160 points (@2x = 320x320 pixels, @3x = 480x480 pixels)
            let resizedLogo = resizeImage(logoImage, targetSize: CGSize(width: 320, height: 320))
            return resizedLogo.pngData()
        }
        
        // Fallback: Try Cloudflare Worker for logo search (if company name is available)
        if let companyName = companyName, !companyName.isEmpty {
            do {
                return try await cloudFlareIntegrator.fetchLogo(companyName: companyName)
            } catch {
                print("Failed to fetch logo from Cloudflare: \(error)")
            }
        }
        
        // Ultimate fallback: Generate a simple placeholder logo with company initials
        if let companyName = companyName, !companyName.isEmpty {
            return generatePlaceholderLogo(for: companyName).pngData()
        }
        
        return nil
    }
    
    private func extractLogoFromImage(_ image: UIImage) async throws -> UIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: nil)
                return
            }
            
            // Use Vision to detect rectangular regions (potential logos)
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    print("Rectangle detection error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Find the smallest rectangle in the top portion (likely a logo)
                let topPortionObservations = observations.filter { obs in
                    // Logo is usually in the top 40% of the card
                    obs.boundingBox.midY > 0.6
                }
                
                guard let logoObservation = topPortionObservations.min(by: { obs1, obs2 in
                    let area1 = obs1.boundingBox.width * obs1.boundingBox.height
                    let area2 = obs2.boundingBox.width * obs2.boundingBox.height
                    return area1 < area2
                }) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Crop the logo region
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                let cropRect = VNImageRectForNormalizedRect(
                    logoObservation.boundingBox,
                    Int(imageSize.width),
                    Int(imageSize.height)
                )
                
                if let croppedImage = cgImage.cropping(to: cropRect) {
                    continuation.resume(returning: UIImage(cgImage: croppedImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            request.minimumAspectRatio = 0.5
            request.maximumAspectRatio = 2.0
            request.minimumSize = 0.05
            request.maximumObservations = 10
            request.minimumConfidence = 0.6
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform logo detection: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func generatePlaceholderLogo(for companyName: String) -> UIImage {
        // Logo size for Apple Wallet: 160x160 points (@2x = 320x320 pixels)
        let size = CGSize(width: 320, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background circle
            UIColor.systemBlue.setFill()
            let circle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circle.fill()
            
            // Get initials (first 2 characters or first letter of first 2 words)
            let words = companyName.split(separator: " ")
            let initials: String
            if words.count >= 2 {
                initials = String(words[0].prefix(1) + words[1].prefix(1))
            } else {
                initials = String(companyName.prefix(2))
            }
            
            // Draw initials
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            
            let text = initials.uppercased()
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func createGraphic(from image: UIImage, extractedData: ExtractedCardData) async throws -> Data? {
        // Create a banner graphic for the Apple Wallet pass
        // Standard pass banner size is 320x120 points (640x240 pixels @2x)
        guard let cgImage = image.cgImage else {
            return image.jpegData(compressionQuality: 0.8)
        }
        
        let colors = try await fetchColors(from: image)
        
        // Create professional banner from original image
        return try await createWalletBanner(
            from: image,
            cgImage: cgImage,
            colors: colors,
            companyName: extractedData.companyName ?? "",
            cardName: extractedData.cardName ?? ""
        )
    }
    
    private func createWalletBanner(
        from originalImage: UIImage,
        cgImage: CGImage,
        colors: [String],
        companyName: String,
        cardName: String
    ) async throws -> Data? {
        // Apple Wallet strip image size for store cards: 375x123 points (@3x = 1125x369 pixels)
        // Using @2x: 750x246 pixels for better quality
        let bannerSize = CGSize(width: 750, height: 246)
        let renderer = UIGraphicsImageRenderer(size: bannerSize)
        
        let bannerImage = renderer.image { context in
            let ctx = context.cgContext
            
            // 1. Fill background with gradient from extracted colors
            if let primaryColorHex = colors.first,
               let secondaryColorHex = colors.dropFirst().first ?? colors.first,
               let primaryColor = Color(hex: primaryColorHex)?.cgColor,
               let secondaryColor = Color(hex: secondaryColorHex)?.cgColor {
                
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [primaryColor, secondaryColor] as CFArray,
                    locations: [0.0, 1.0]
                )
                
                if let gradient = gradient {
                    ctx.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: 0, y: 0),
                        end: CGPoint(x: bannerSize.width, y: bannerSize.height),
                        options: []
                    )
                }
            } else {
                // Fallback to blue gradient
                UIColor.systemBlue.setFill()
                ctx.fill(CGRect(origin: .zero, size: bannerSize))
            }
            
            // 2. Add subtle pattern/texture from original image
            ctx.saveGState()
            ctx.setAlpha(0.15)
            
            // Draw scaled and cropped original image
            let aspectRatio = CGFloat(cgImage.width) / CGFloat(cgImage.height)
            var drawRect: CGRect
            
            if aspectRatio > (bannerSize.width / bannerSize.height) {
                // Image is wider - fit to height
                let scaledWidth = bannerSize.height * aspectRatio
                let offsetX = (bannerSize.width - scaledWidth) / 2
                drawRect = CGRect(x: offsetX, y: 0, width: scaledWidth, height: bannerSize.height)
            } else {
                // Image is taller - fit to width
                let scaledHeight = bannerSize.width / aspectRatio
                let offsetY = (bannerSize.height - scaledHeight) / 2
                drawRect = CGRect(x: 0, y: offsetY, width: bannerSize.width, height: scaledHeight)
            }
            
            ctx.draw(cgImage, in: drawRect)
            ctx.restoreGState()
            
            // 3. Add subtle overlay for better text readability
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.2).cgColor)
            ctx.fill(CGRect(origin: .zero, size: bannerSize))
        }
        
        return bannerImage.pngData()
    }
    
    private func updateProgress(_ progress: Double, status: String) {
        Task { @MainActor in
            self.processingProgress = progress
            print("Processing: \(Int(progress * 100))% - \(status)")
        }
    }
}

// MARK: - Foundation Models Integration

@Generable(description: "Structured data extracted from a loyalty card")
struct ExtractedCardData: Codable, Equatable {
    @Guide(description: "The name or title of the loyalty card")
    var cardName: String?
    
    @Guide(description: "The company or organization name")
    var companyName: String?
    
    @Guide(description: "Any barcode or QR code number found")
    var barcodeString: String?
    
    @Guide(description: "The format of the barcode: QR, Code128, Code39, etc.")
    var barcodeFormat: String?
    
    @Guide(description: "Description of any logo visible on the card")
    var logoDescription: String?
    
    @Guide(description: "Description of the graphic design showing in the background of the card (e.g. stars, stripes,geometric shapes, etc.) without texts and layout")
    var graphicDescription: String?
    
    @Guide(description: "Expiration date if visible (format: MM/YY or MM/YYYY)")
    var expirationDate: String?
    
    @Guide(description: "Membership or customer number")
    var membershipNumber: String?
    
    @Guide(description: "Any additional text fields or information", .count(0...5))
    var additionalText: [String]?
}

// MARK: - Data Conversion

extension ExtractedCardData {
    func toCardData() -> CardData {
        return CardData(
            cardName: cardName,
            companyName: companyName,
            barcodeString: barcodeString,
            barcodeFormat: barcodeFormat,
            logoDescription: logoDescription,
            graphicDescription: graphicDescription,
            expirationDate: expirationDate,
            membershipNumber: membershipNumber,
            additionalText: additionalText
        )
    }
}

// MARK: - CloudFlare Integration

@Observable
final class CloudFlareIntegrator {
    private let baseURL = "https://your-worker.your-subdomain.workers.dev"
    
    func fetchLogo(companyName: String) async throws -> Data? {
        guard !companyName.isEmpty else { return nil }
        
        guard let url = URL(string: "\(baseURL)/logo") else {
            throw CloudFlareError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["companyName": companyName]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil // Logo not found, not an error
        }
        
        return data
    }
    
    func generatePass(payload: PassPayload) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/generate-pass") else {
            throw CloudFlareError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(payload)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudFlareError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CloudFlareError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
}

enum CloudFlareError: LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError:
            return "Network connection failed"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - Supporting Types

enum CardProcessingError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    case foundationModelsUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image is invalid"
        case .noTextFound:
            return "No text was found in the image"
        case .processingFailed:
            return "Failed to process the card"
        case .foundationModelsUnavailable:
            return "Apple Intelligence is not available on this device"
        }
    }
}



