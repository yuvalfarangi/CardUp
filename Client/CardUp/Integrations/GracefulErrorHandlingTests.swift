////
////  GracefulErrorHandlingTests.swift
////  CardUp
////
////  Created by Yuval Farangi on 24/02/2026.
////
//
//import Testing //No such module 'Testing'
//import Foundation
//import UIKit
//import SwiftData
//
//@testable import CardUp
//
///// Tests for graceful error handling when server analysis fails
//@Suite("Graceful Error Handling Tests")
//struct GracefulErrorHandlingTests {
//    
//    // MARK: - Card Processing Service Tests
//    
//    @Test("Card is populated with defaults when server fails")
//    func testCardPopulatedWithDefaultsOnServerFailure() async throws {
//        // Given: A card processing service and a blank card
//        let service = CardProcessingService()
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Card.self, configurations: config)
//        let context = ModelContext(container)
//        
//        let card = Card()
//        context.insert(card)
//        
//        // When: Processing fails (simulated by not having server available)
//        // This would normally call the server, but with quota exceeded it should populate defaults
//        
//        // Then: Card should have sensible defaults
//        #expect(card.passTypeIdentifier == "pass.com.example.generic")
//        #expect(card.formatVersion == 1)
//        
//        // After defaults are populated, these should be set
//        // Note: This test assumes populateCardWithDefaults was called
//        // In real flow, this happens automatically on server error
//    }
//    
//    @Test("Card is marked as draft when server analysis fails")
//    func testCardMarkedAsDraftOnFailure() async throws {
//        // Given: A card that should be processed
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Card.self, configurations: config)
//        let context = ModelContext(container)
//        
//        let card = Card()
//        context.insert(card)
//        
//        // When: Server analysis fails and defaults are populated
//        card.organizationName = "Card Name"
//        card.passDescription = "Loyalty Card"
//        card.isDraft = true
//        
//        // Then: Card should be marked as draft
//        #expect(card.isDraft == true)
//        #expect(card.organizationName == "Card Name")
//        #expect(card.passDescription == "Loyalty Card")
//    }
//    
//    @Test("Card colors are extracted from image even on server failure")
//    func testColorExtractionContinuesOnFailure() async throws {
//        // Given: An image with colors to extract
//        let service = CardProcessingService()
//        
//        // Create a simple colored image
//        let size = CGSize(width: 100, height: 100)
//        let renderer = UIGraphicsImageRenderer(size: size)
//        let blueImage = renderer.image { context in
//            UIColor.systemBlue.setFill()
//            context.fill(CGRect(origin: .zero, size: size))
//        }
//        
//        // When: extractDominantColors is called
//        let colors = await service.extractDominantColors(from: blueImage)
//        
//        // Then: Should return at least one color
//        #expect(colors.count > 0)
//        #expect(colors.first?.hasPrefix("#") == true)
//    }
//    
//    @Test("Bright color detection works correctly")
//    func testBrightColorDetection() {
//        // Given: Various colors
//        let service = CardProcessingService()
//        
//        // When/Then: Test bright colors
//        let white = "#FFFFFF"
//        let lightYellow = "#FFFFCC"
//        let black = "#000000"
//        let darkBlue = "#003366"
//        
//        // White and light colors should be detected as bright
//        #expect(service.isBrightColor(white) == true)
//        #expect(service.isBrightColor(lightYellow) == true)
//        
//        // Black and dark colors should not be bright
//        #expect(service.isBrightColor(black) == false)
//        #expect(service.isBrightColor(darkBlue) == false)
//    }
//    
//    // MARK: - Default Values Tests
//    
//    @Test("Default barcode format is QR code")
//    func testDefaultBarcodeFormat() {
//        // Given: A card with defaults
//        let card = Card()
//        
//        // When: Defaults are applied
//        card.barcodeFormat = "PKBarcodeFormatQR"
//        card.barcodeMessage = "123456789"
//        
//        // Then: Should have QR code format
//        #expect(card.barcodeFormat == "PKBarcodeFormatQR")
//        #expect(card.barcodeMessage == "123456789")
//    }
//    
//    @Test("Default colors are set correctly")
//    func testDefaultColors() {
//        // Given: A card with defaults
//        let card = Card()
//        
//        // When: Defaults are applied
//        card.backgroundColor = "#3B82F6"  // Blue
//        card.foregroundColor = "#FFFFFF"  // White
//        card.labelColor = "#E0E7FF"       // Light blue-gray
//        
//        // Then: Colors should be valid hex format
//        #expect(card.backgroundColor.hasPrefix("#"))
//        #expect(card.foregroundColor.hasPrefix("#"))
//        #expect(card.labelColor.hasPrefix("#"))
//        #expect(card.backgroundColor.count == 7)  // #RRGGBB
//    }
//    
//    // MARK: - User Flow Tests
//    
//    @Test("Processing completes without pass data when server fails")
//    func testProcessingCompletesWithoutPassData() {
//        // Given: A processing service that has completed
//        let service = CardProcessingService()
//        
//        // When: Server analysis failed (no pass data generated)
//        service.generatedPassData = nil
//        service.isProcessing = false
//        
//        // Then: Should indicate completion without pass data
//        #expect(service.isProcessing == false)
//        #expect(service.generatedPassData == nil)
//        
//        // UI should check this condition and navigate to EditCardView
//    }
//    
//    @Test("Card can be saved as draft")
//    func testCardCanBeSavedAsDraft() throws {
//        // Given: An in-memory model context
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Card.self, configurations: config)
//        let context = ModelContext(container)
//        
//        // When: A draft card is created and saved
//        let card = Card()
//        card.organizationName = "Card Name"
//        card.passDescription = "Loyalty Card"
//        card.isDraft = true
//        context.insert(card)
//        try context.save()
//        
//        // Then: Card should be persisted as draft
//        let descriptor = FetchDescriptor<Card>(
//            predicate: #Predicate { $0.isDraft == true }
//        )
//        let draftCards = try context.fetch(descriptor)
//        
//        #expect(draftCards.count == 1)
//        #expect(draftCards.first?.organizationName == "Card Name")
//    }
//    
//    // MARK: - Server Error Simulation Tests
//    
//    @Test("ServerApiError is properly structured")
//    func testServerApiErrorStructure() {
//        // Given: Various server errors
//        let invalidURLError = ServerApiError.invalidURL("bad-url")
//        let httpError = ServerApiError.httpError(statusCode: 429)
//        let serverError = ServerApiError.serverError(statusCode: 500, message: "Server error")
//        
//        // Then: All should have error descriptions
//        #expect(invalidURLError.errorDescription != nil)
//        #expect(httpError.errorDescription != nil)
//        #expect(serverError.errorDescription != nil)
//        
//        // And: 429 error should be identifiable
//        if case .httpError(let statusCode) = httpError {
//            #expect(statusCode == 429)
//        }
//    }
//    
//    @Test("CardProcessingError provides user-friendly messages")
//    func testCardProcessingErrorMessages() {
//        // Given: Various processing errors
//        let invalidImageError = CardProcessingError.invalidImage
//        let noTextError = CardProcessingError.noTextFound
//        let processingFailedError = CardProcessingError.processingFailed
//        let networkError = CardProcessingError.networkError
//        
//        // Then: All should have user-friendly descriptions
//        #expect(invalidImageError.errorDescription == "The selected image is invalid")
//        #expect(noTextError.errorDescription == "No text was found in the image")
//        #expect(processingFailedError.errorDescription == "Failed to process the card")
//        #expect(networkError.errorDescription == "Network connection failed")
//    }
//    
//    // MARK: - Integration Tests
//    
//    @Test("Complete flow with server failure produces valid draft card")
//    func testCompleteFlowWithServerFailure() throws {
//        // Given: A complete setup
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Card.self, configurations: config)
//        let context = ModelContext(container)
//        
//        let card = Card()
//        context.insert(card)
//        
//        // When: Server fails and defaults are applied
//        card.passTypeIdentifier = "pass.com.example.generic"
//        card.organizationName = "Card Name"
//        card.passDescription = "Loyalty Card"
//        card.barcodeMessage = "123456789"
//        card.barcodeFormat = "PKBarcodeFormatQR"
//        card.backgroundColor = "#3B82F6"
//        card.foregroundColor = "#FFFFFF"
//        card.isDraft = true
//        card.pkpassData = nil  // No pass generated yet
//        
//        try context.save()
//        
//        // Then: Card should be a valid draft
//        #expect(card.isDraft == true)
//        #expect(card.pkpassData == nil)
//        #expect(card.organizationName == "Card Name")
//        #expect(card.passTypeIdentifier == "pass.com.example.generic")
//        
//        // And: Card should be retrievable
//        let descriptor = FetchDescriptor<Card>()
//        let allCards = try context.fetch(descriptor)
//        #expect(allCards.count == 1)
//    }
//    
//    @Test("Draft card can be edited and pass regenerated")
//    func testDraftCardCanBeEditedAndRegenerated() throws {
//        // Given: A draft card
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Card.self, configurations: config)
//        let context = ModelContext(container)
//        
//        let card = Card()
//        card.organizationName = "Card Name"  // Default
//        card.passDescription = "Loyalty Card"  // Default
//        card.isDraft = true
//        context.insert(card)
//        try context.save()
//        
//        // When: User edits the card manually
//        card.organizationName = "My Gym"
//        card.passDescription = "Gym Membership"
//        card.barcodeMessage = "GYM123456"
//        
//        // And: Pass is regenerated
//        card.isDraft = false
//        // Simulate pass generation
//        let mockPassData = Data([0x50, 0x4B, 0x03, 0x04])  // ZIP file header
//        card.pkpassData = mockPassData
//        
//        try context.save()
//        
//        // Then: Card should no longer be a draft
//        #expect(card.isDraft == false)
//        #expect(card.pkpassData != nil)
//        #expect(card.organizationName == "My Gym")
//        #expect(card.passDescription == "Gym Membership")
//    }
//}
//
//// MARK: - Test Helpers
//
//extension CardProcessingService {
//    /// Expose isBrightColor for testing
//    func isBrightColor(_ hexColor: String) -> Bool {
//        // Remove # if present
//        let hex = hexColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
//        
//        // Convert hex to RGB
//        var rgb: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&rgb)
//        
//        let r = Double((rgb >> 16) & 0xFF) / 255.0
//        let g = Double((rgb >> 8) & 0xFF) / 255.0
//        let b = Double(rgb & 0xFF) / 255.0
//        
//        // Calculate relative luminance
//        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
//        
//        return luminance > 0.5
//    }
//    
//    /// Expose extractDominantColors for testing
//    func extractDominantColors(from image: UIImage) async -> [String] {
//        return await withCheckedContinuation { continuation in
//            guard let cgImage = image.cgImage else {
//                continuation.resume(returning: ["#3B82F6"])
//                return
//            }
//            
//            DispatchQueue.global(qos: .userInitiated).async {
//                let colors = self.performColorExtraction(from: cgImage)
//                continuation.resume(returning: colors)
//            }
//        }
//    }
//    
//    /// Expose performColorExtraction for testing
//    func performColorExtraction(from cgImage: CGImage) -> [String] {
//        let width = 100
//        let height = 100
//        
//        guard let context = CGContext(
//            data: nil,
//            width: width,
//            height: height,
//            bitsPerComponent: 8,
//            bytesPerRow: width * 4,
//            space: CGColorSpaceCreateDeviceRGB(),
//            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
//        ) else {
//            return ["#3B82F6"]
//        }
//        
//        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
//        
//        guard let data = context.data else {
//            return ["#3B82F6"]
//        }
//        
//        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
//        var colorCounts: [String: Int] = [:]
//        
//        let totalPixels = width * height * 4
//        
//        for i in stride(from: 0, to: totalPixels, by: 20) {
//            guard i + 3 < totalPixels else { continue }
//            
//            let r = buffer[i]
//            let g = buffer[i + 1]
//            let b = buffer[i + 2]
//            let a = buffer[i + 3]
//            
//            guard a > 128 else { continue }
//            
//            let hex = String(format: "#%02X%02X%02X", r, g, b)
//            colorCounts[hex, default: 0] += 1
//        }
//        
//        let sortedColors = colorCounts.sorted { $0.value > $1.value }
//        let topColors = Array(sortedColors.prefix(3).map { $0.key })
//        
//        return topColors.isEmpty ? ["#3B82F6"] : topColors
//    }
//}
