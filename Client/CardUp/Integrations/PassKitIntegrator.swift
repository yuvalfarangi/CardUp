//
//  PassKitIntegrator.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import PassKit
import UIKit
import SwiftUI

// Type alias for backward compatibility
typealias ExtractedCardData = CardData

@Observable
final class PassKitIntegrator {
    var isGenerating: Bool = false
    var error: String?
    
    // Development mode flag - set to true to use mock passes without CloudFlare Worker
    private let useMockPassGeneration = true
    
    // MARK: - Pass Generation
    
    func generateWalletPass(for card: Card, with extractedData: ExtractedCardData) async throws -> Data {
        isGenerating = true
        defer { isGenerating = false }
        
        // Create pass payload
        let payload = PassPayload(
            cardId: card.id.uuidString,
            passType: card.passType,
            organizationName: extractedData.companyName ?? "Unknown Company",
            description: extractedData.cardName ?? "Loyalty Card",
            logoText: extractedData.companyName ?? "",
            barcodeString: card.barcodeString,
            barcodeFormat: card.barcodeFormat,
            dominantColors: card.dominantColorsHex,
            logoImageData: card.logoImageData,
            bannerImageData: card.bannerImageData,
            membershipNumber: extractedData.membershipNumber,
            expirationDate: extractedData.expirationDate,
            additionalFields: extractedData.additionalText ?? []
        )
        
        // Use mock pass generation for development/testing
        // In production, you'll need to configure the CloudFlare Worker
        let passData: Data
        
        if useMockPassGeneration {
            print("🔧 Using mock pass generation (CloudFlare Worker not configured)")
            passData = try await generateMockPass(payload: payload, card: card)
        } else {
            print("🌐 Using CloudFlare Worker for pass generation")
            passData = try await requestPassGeneration(payload: payload)
        }
        
        // Store the generated pass data
        card.pkpassData = passData
        
        return passData
    }
    
    /// Generate Apple Wallet pass from Gemini analysis
    func generateWalletPassFromGemini(
        for card: Card,
        with geminiResponse: GeminiCardAnalysisResponse
    ) async throws -> Data {
        isGenerating = true
        defer { isGenerating = false }
        
        let details = geminiResponse.cardDetails
        
        // Build payload from Gemini response
        let payload = PassPayload(
            cardId: card.id.uuidString,
            passType: geminiResponse.passFormat.rawValue,
            organizationName: details.organizationName ?? card.displayName,
            description: details.description ?? "Card",
            logoText: details.logoText ?? details.organizationName ?? "",
            barcodeString: details.barcodeMessage ?? card.barcodeString,
            barcodeFormat: details.barcodeFormat ?? "PKBarcodeFormatQR",
            dominantColors: card.dominantColorsHex,
            logoImageData: card.logoImageData,
            bannerImageData: card.bannerImageData,
            membershipNumber: extractMembershipNumber(from: details),
            expirationDate: details.expirationDate,
            additionalFields: extractAdditionalFields(from: details)
        )
        
        // Use mock pass generation for development/testing
        let passData: Data
        
        if useMockPassGeneration {
            print("🔧 Using mock pass generation (CloudFlare Worker not configured)")
            passData = try await generateMockPass(payload: payload, card: card)
        } else {
            print("🌐 Using CloudFlare Worker for pass generation")
            passData = try await requestPassGeneration(payload: payload)
        }
        
        // Store the generated pass data
        card.pkpassData = passData
        
        return passData
    }
    
    // Helper to extract membership number from various Gemini formats
    private func extractMembershipNumber(from details: GeminiCardDetails) -> String? {
        // Check store card specific info
        if let storeInfo = details.storeCardInfo, let memberNumber = storeInfo.membershipNumber {
            return memberNumber
        }
        
        // Check primary fields
        if let primaryFields = details.primaryFields {
            for field in primaryFields {
                if field.key.lowercased().contains("member") || 
                   field.key.lowercased().contains("account") {
                    return field.value
                }
            }
        }
        
        return nil
    }
    
    // Helper to extract additional fields from Gemini response
    private func extractAdditionalFields(from details: GeminiCardDetails) -> [String] {
        var fields: [String] = []
        
        // Combine all fields into additional text
        let allFields = (details.headerFields ?? []) + 
                       (details.primaryFields ?? []) + 
                       (details.secondaryFields ?? []) + 
                       (details.auxiliaryFields ?? [])
        
        for field in allFields {
            if let label = field.label {
                fields.append("\(label): \(field.value)")
            } else {
                fields.append(field.value)
            }
        }
        
        return Array(fields.prefix(5)) // Limit to 5 additional fields
    }
    
    func addPassToWallet(passData: Data) throws -> PKAddPassesViewController? {
        // Check if this is mock data
        if let jsonObject = try? JSONSerialization.jsonObject(with: passData) as? [String: Any],
           jsonObject["_mock"] as? Bool == true {
            // This is mock data - we can't actually add it to Apple Wallet
            // Throw a specific error to inform the user
            throw PassKitError.mockPassData
        }
        
        guard let pass = try? PKPass(data: passData) else {
            throw PassKitError.invalidPassData
        }
        
        guard PKAddPassesViewController.canAddPasses() else {
            throw PassKitError.passKitNotAvailable
        }
        
        let addPassVC = PKAddPassesViewController(pass: pass)
        return addPassVC
    }
    
    private func requestPassGeneration(payload: PassPayload) async throws -> Data {
        // Log the payload being sent to server
        print("📤 Sending pass generation request to server")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 Payload Details:")
        print("  • Card ID: \(payload.cardId)")
        print("  • Pass Type: \(payload.passType)")
        print("  • Organization: \(payload.organizationName)")
        print("  • Description: \(payload.description)")
        print("  • Logo Text: \(payload.logoText)")
        print("  • Barcode String: \(payload.barcodeString)")
        print("  • Barcode Format: \(payload.barcodeFormat)")
        print("  • Dominant Colors: \(payload.dominantColors)")
        print("  • Logo Image: \(payload.logoImageData != nil ? "✓ Present (\(payload.logoImageData!.count) bytes)" : "✗ None")")
        print("  • Banner Image: \(payload.bannerImageData != nil ? "✓ Present (\(payload.bannerImageData!.count) bytes)" : "✗ None")")
        print("  • Membership Number: \(payload.membershipNumber ?? "None")")
        print("  • Expiration Date: \(payload.expirationDate ?? "None")")
        print("  • Additional Fields: \(payload.additionalFields.isEmpty ? "None" : "\(payload.additionalFields.count) fields")")
        
        // Log additional fields in detail if present
        if !payload.additionalFields.isEmpty {
            print("  • Field Values:")
            for (index, field) in payload.additionalFields.enumerated() {
                print("    \(index + 1). \(field)")
            }
        }
        
        // Serialize payload to JSON for detailed inspection
        if let jsonData = try? JSONEncoder().encode(payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\n📄 JSON Payload:")
            print(jsonString)
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Use the ServerApi to request pass generation from the backend
        do {
            // Send the payload to the server's generate-pass endpoint
            let passData: Data = try await ServerApi.shared.post(
                endpoint: "/generate-pass",
                body: payload
            )
            
            print("✅ Server responded with pass data (\(passData.count) bytes)")
            
            return passData
        } catch let error as ServerApiError {
            print("❌ Server request failed: \(error)")
            // Map ServerApiError to PassKitError
            switch error {
            case .networkError(let underlyingError):
                throw PassKitError.networkError(underlyingError)
            default:
                throw PassKitError.serverError
            }
        }
    }
    
    // MARK: - Mock Pass Generation (Development Mode)
    
    /// Generates a mock pass data for development/testing without CloudFlare Worker
    /// This creates a placeholder Data object that simulates a pass
    /// In production, replace this with actual CloudFlare Worker integration
    private func generateMockPass(payload: PassPayload, card: Card) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Create a mock pass representation
        // Note: This is NOT a real .pkpass file (which requires Apple Developer signing)
        // It's just mock data to allow the app to function without the backend
        
        // Build fields based on available data
        var primaryFields: [[String: Any]] = []
        var secondaryFields: [[String: Any]] = []
        var auxiliaryFields: [[String: Any]] = []
        
        // Add membership number as primary field if available
        if let membershipNumber = payload.membershipNumber, !membershipNumber.isEmpty {
            primaryFields.append([
                "key": "member",
                "label": "MEMBER",
                "value": membershipNumber
            ])
        }
        
        // Add expiration date as secondary field if available
        if let expirationDate = payload.expirationDate, !expirationDate.isEmpty {
            secondaryFields.append([
                "key": "expires",
                "label": "EXPIRES",
                "value": expirationDate
            ])
        }
        
        // Add additional fields as auxiliary fields
        if !payload.additionalFields.isEmpty {
            for (index, field) in payload.additionalFields.prefix(3).enumerated() {
                auxiliaryFields.append([
                    "key": "field\(index)",
                    "label": "INFO",
                    "value": field
                ])
            }
        }
        
        // Prepare barcode data
        var barcodeDict: [String: Any] = [
            "message": payload.barcodeString,
            "format": mapBarcodeFormat(payload.barcodeFormat),
            "messageEncoding": "iso-8859-1"
        ]
        
        let mockPassDict: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass.com.yourcompany.cardUp.\(payload.passType)",
            "serialNumber": payload.cardId,
            "teamIdentifier": "YOUR_TEAM_ID",
            "organizationName": payload.organizationName,
            "description": payload.description,
            "logoText": payload.logoText,
            "foregroundColor": "rgb(255, 255, 255)",
            "backgroundColor": payload.dominantColors.first ?? "rgb(59, 130, 246)",
            "labelColor": "rgb(255, 255, 255)",
            "barcode": barcodeDict,
            "storeCard": [
                "headerFields": [],
                "primaryFields": primaryFields,
                "secondaryFields": secondaryFields,
                "auxiliaryFields": auxiliaryFields,
                "backFields": [
                    [
                        "key": "company",
                        "label": "Company",
                        "value": payload.organizationName
                    ],
                    [
                        "key": "cardType",
                        "label": "Card Type",
                        "value": payload.description
                    ]
                ]
            ] as [String : Any],
            "_mock": true,
            "_note": "This is mock data. Configure CloudFlare Worker for real .pkpass generation"
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: mockPassDict, options: .prettyPrinted)
        
        return jsonData
    }
    
    private func mapBarcodeFormat(_ format: String) -> String {
        let normalized = format.lowercased()
        if normalized.contains("qr") {
            return "PKBarcodeFormatQR"
        } else if normalized.contains("128") {
            return "PKBarcodeFormatCode128"
        } else if normalized.contains("pdf417") {
            return "PKBarcodeFormatPDF417"
        } else if normalized.contains("aztec") {
            return "PKBarcodeFormatAztec"
        } else {
            return "PKBarcodeFormatQR" // Default to QR
        }
    }
}

// MARK: - Pass Payload Structure

struct PassPayload: Codable {
    let cardId: String
    let passType: String
    let organizationName: String
    let description: String
    let logoText: String
    let barcodeString: String
    let barcodeFormat: String
    let dominantColors: [String]
    let logoImageData: Data?
    let bannerImageData: Data?
    let membershipNumber: String?
    let expirationDate: String?
    let additionalFields: [String]
}

// MARK: - Error Handling

enum PassKitError: LocalizedError {
    case passKitNotAvailable
    case invalidPassData
    case mockPassData
    case invalidURL
    case serverError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .passKitNotAvailable:
            return "PassKit is not available on this device"
        case .invalidPassData:
            return "The generated pass data is invalid"
        case .mockPassData:
            return "Development Mode: Configure CloudFlare Worker to add passes to Apple Wallet. The pass data is saved and can be edited."
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server error occurred while generating pass"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Integration

extension View {
    func addPassToWallet(passData: Data?, onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) -> some View {
        self.background(
            PassKitRepresentable(
                passData: passData,
                onSuccess: onSuccess,
                onError: onError
            )
        )
    }
}

struct PassKitRepresentable: UIViewControllerRepresentable {
    let passData: Data?
    let onSuccess: () -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let passData = passData else { return }
        
        do {
            let passKitIntegrator = PassKitIntegrator()
            if let addPassVC = try passKitIntegrator.addPassToWallet(passData: passData) {
                addPassVC.delegate = context.coordinator
                
                DispatchQueue.main.async {
                    uiViewController.present(addPassVC, animated: true)
                }
            }
        } catch {
            onError(error)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onSuccess: onSuccess, onError: onError)
    }
    
    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onSuccess: () -> Void
        let onError: (Error) -> Void
        
        init(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onSuccess = onSuccess
            self.onError = onError
        }
        
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) {
                self.onSuccess()
            }
        }
    }
}
