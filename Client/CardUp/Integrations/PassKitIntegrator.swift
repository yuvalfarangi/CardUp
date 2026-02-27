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
    
    // Set to false now that the Node.js server signs real passes.
    // Set back to true if you need to run without the server.
    private let useMockPassGeneration = false
    
    // MARK: - Pass Generation
    
    func generateWalletPass(for card: Card, with extractedData: ExtractedCardData) async throws -> Data {
        isGenerating = true
        defer { isGenerating = false }

        let orgName = extractedData.companyName ?? (card.organizationName.isEmpty ? "Card" : card.organizationName)
        let desc    = extractedData.cardName    ?? (card.passDescription.isEmpty   ? "Card" : card.passDescription)

        let payload = GenericPassPayload(
            formatVersion:          card.formatVersion,
            passTypeIdentifier:     card.passTypeIdentifier,
            serialNumber:           card.serialNumber.isEmpty ? card.id.uuidString : card.serialNumber,
            teamIdentifier:         "UNKNOWN",
            organizationName:       orgName,
            description:            desc,
            logoText:               orgName,
            passStyle:              card.passStyle.isEmpty ? "generic" : card.passStyle,
            barcodeMessage:         card.barcodeMessage,
            barcodeFormat:          card.barcodeFormat.isEmpty ? "PKBarcodeFormatQR" : card.barcodeFormat,
            barcodeMessageEncoding: card.barcodeMessageEncoding.isEmpty ? "iso-8859-1" : card.barcodeMessageEncoding,
            foregroundColor:        card.foregroundColor.isEmpty ? "#FFFFFF" : card.foregroundColor,
            backgroundColor:        card.backgroundColor.isEmpty ? "#1A1A2E" : card.backgroundColor,
            labelColor:             card.labelColor,
            headerFields:           card.headerFields,
            primaryFields:          card.primaryFields,
            secondaryFields:        card.secondaryFields,
            auxiliaryFields:        card.auxiliaryFields,
            backFields:             card.backFields,
            logoImageData:          card.getLogoImageDataForPass(),
            bannerImageData:        card.bannerImageData,
            expirationDate:         extractedData.expirationDate ?? card.expirationDate,
            relevantDate:           card.relevantDate
        )

        let passData: Data
        if useMockPassGeneration {
            print("🔧 Using mock pass generation")
            passData = try await generateMockPassFromGeneric(payload: payload, card: card)
        } else {
            print("🌐 Using server for pass generation")
            passData = try await requestGenericPassGeneration(payload: payload)
        }

        card.pkpassData = passData

        if let signedPass = try? PKPass(data: passData) {
            card.passTypeIdentifier = signedPass.passTypeIdentifier
            card.serialNumber       = signedPass.serialNumber
        }

        return passData
    }
    
    /// Generate Apple Wallet pass from Gemini analysis (Generic pass format)
    func generateWalletPassFromGemini(
        for card: Card,
        with geminiResponse: GeminiCardAnalysisResponse
    ) async throws -> Data {
        isGenerating = true
        defer { isGenerating = false }
        
        let details = geminiResponse.cardDetails
        
        // Build payload from Card model (which now contains all PassKit Generic fields)
        let payload = GenericPassPayload(
            // Pass identifiers
            formatVersion: card.formatVersion,
            passTypeIdentifier: card.passTypeIdentifier,
            serialNumber: card.serialNumber,
            teamIdentifier: "YOUR_TEAM_ID", // TODO: Replace with your actual Team ID
            organizationName: card.organizationName,
            description: card.passDescription,
            logoText: card.logoText,

            // Pass style (explicit, not derived from identifier)
            passStyle: card.passStyle.isEmpty ? "generic" : card.passStyle,

            // Barcode
            barcodeMessage: card.barcodeMessage,
            barcodeFormat: card.barcodeFormat,
            barcodeMessageEncoding: card.barcodeMessageEncoding,

            // Colors
            foregroundColor: card.foregroundColor,
            backgroundColor: card.backgroundColor,
            labelColor: card.labelColor,

            // Generic fields
            headerFields: card.headerFields,
            primaryFields: card.primaryFields,
            secondaryFields: card.secondaryFields,
            auxiliaryFields: card.auxiliaryFields,
            backFields: card.backFields,

            // Images
            logoImageData: card.getLogoImageDataForPass(),
            bannerImageData: card.bannerImageData,

            // Dates
            expirationDate: card.expirationDate,
            relevantDate: card.relevantDate
        )
        
        // Use mock pass generation for development/testing
        let passData: Data

        if useMockPassGeneration {
            print("🔧 Using mock pass generation (CloudFlare Worker not configured)")
            passData = try await generateMockPassFromGeneric(payload: payload, card: card)
        } else {
            print("🌐 Using server for pass generation")
            passData = try await requestGenericPassGeneration(payload: payload)
        }

        // Store the generated pass data
        card.pkpassData = passData

        // Sync the card's identifiers with what the server actually signed.
        // The server may override passTypeIdentifier from its env var, so we
        // read it back from the signed PKPass to keep PKPassLibrary queries accurate.
        if let signedPass = try? PKPass(data: passData) {
            card.passTypeIdentifier = signedPass.passTypeIdentifier
            card.serialNumber       = signedPass.serialNumber
        }

        return passData
    }
    
    /// Add a pass to Apple Wallet using PKAddPassesViewController
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
    
    // MARK: - Legacy Pass Generation (deprecated - use Generic format)
    
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
    
    /// Generates a mock pass from legacy PassPayload structure
    /// This is for backward compatibility with the old generateWalletPass method
    private func generateMockPassFromLegacy(payload: PassPayload, card: Card) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
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
        let barcodeDict: [String: Any] = [
            "message": payload.barcodeString,
            "format": mapBarcodeFormat(payload.barcodeFormat),
            "messageEncoding": "iso-8859-1"
        ]
        
        // Use the appropriate key for the pass style (generic, storeCard, coupon, eventTicket)
        let passStyleKey = payload.passType
        let passStyleDict: [String: Any] = [
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
                ],
                [
                    "key": "passStyle",
                    "label": "Pass Style",
                    "value": passStyleKey
                ]
            ]
        ]
        
        var mockPassDict: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass.com.yourcompany.cardUp.\(passStyleKey)",
            "serialNumber": payload.cardId,
            "teamIdentifier": "YOUR_TEAM_ID",
            "organizationName": payload.organizationName,
            "description": payload.description,
            "logoText": payload.logoText,
            "foregroundColor": "rgb(255, 255, 255)",
            "backgroundColor": payload.dominantColors.first ?? "rgb(59, 130, 246)",
            "labelColor": "rgb(255, 255, 255)",
            "barcode": barcodeDict,
            passStyleKey: passStyleDict,
            "_mock": true,
            "_note": "This is mock data. Configure CloudFlare Worker for real .pkpass generation",
            "_passStyle": passStyleKey
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: mockPassDict, options: .prettyPrinted)
        
        return jsonData
    }
    
    /// Generates a mock pass data for development/testing without CloudFlare Worker
    /// This creates a placeholder Data object that simulates a pass in Apple PassKit Generic format
    /// In production, replace this with actual CloudFlare Worker integration
    private func generateMockPassFromGeneric(payload: GenericPassPayload, card: Card) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Create a mock pass representation matching Apple PassKit Generic format
        // Note: This is NOT a real .pkpass file (which requires Apple Developer signing)
        // It's just mock data to allow the app to function without the backend
        
        // Convert PassField arrays to dictionaries for JSON
        let headerFieldsDicts = payload.headerFields.map { fieldToDict($0) }
        let primaryFieldsDicts = payload.primaryFields.map { fieldToDict($0) }
        let secondaryFieldsDicts = payload.secondaryFields.map { fieldToDict($0) }
        let auxiliaryFieldsDicts = payload.auxiliaryFields.map { fieldToDict($0) }
        let backFieldsDicts = payload.backFields.map { fieldToDict($0) }
        
        // Build barcode dictionary
        var barcodeDict: [String: Any] = [
            "message": payload.barcodeMessage,
            "format": payload.barcodeFormat,
            "messageEncoding": payload.barcodeMessageEncoding
        ]
        
        // Build generic section - use the appropriate key based on pass style
        // Extract pass style from passTypeIdentifier (e.g., "pass.com.example.storeCard" -> "storeCard")
        let passStyleKey = payload.passTypeIdentifier.components(separatedBy: ".").last ?? "generic"
        
        var genericDict: [String: Any] = [:]
        if !headerFieldsDicts.isEmpty {
            genericDict["headerFields"] = headerFieldsDicts
        }
        if !primaryFieldsDicts.isEmpty {
            genericDict["primaryFields"] = primaryFieldsDicts
        }
        if !secondaryFieldsDicts.isEmpty {
            genericDict["secondaryFields"] = secondaryFieldsDicts
        }
        if !auxiliaryFieldsDicts.isEmpty {
            genericDict["auxiliaryFields"] = auxiliaryFieldsDicts
        }
        if !backFieldsDicts.isEmpty {
            genericDict["backFields"] = backFieldsDicts
        }
        
        // Build complete pass dictionary with the appropriate style key
        var mockPassDict: [String: Any] = [
            "formatVersion": payload.formatVersion,
            "passTypeIdentifier": payload.passTypeIdentifier,
            "serialNumber": payload.serialNumber,
            "teamIdentifier": payload.teamIdentifier,
            "organizationName": payload.organizationName,
            "description": payload.description,
            "foregroundColor": payload.foregroundColor,
            "backgroundColor": payload.backgroundColor,
            "barcode": barcodeDict,
            passStyleKey: genericDict, // Use the extracted style key (generic, storeCard, coupon, eventTicket)
            "_mock": true,
            "_note": "This is mock data. Configure CloudFlare Worker for real .pkpass generation",
            "_passStyle": passStyleKey
        ]
        
        // Add optional fields
        if let logoText = payload.logoText {
            mockPassDict["logoText"] = logoText
        }
        if let labelColor = payload.labelColor {
            mockPassDict["labelColor"] = labelColor
        }
        if let expirationDate = payload.expirationDate {
            mockPassDict["expirationDate"] = expirationDate
        }
        if let relevantDate = payload.relevantDate {
            mockPassDict["relevantDate"] = relevantDate
        }
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: mockPassDict, options: .prettyPrinted)
        
        return jsonData
    }
    
    /// Convert a PassField to a dictionary for JSON serialization
    private func fieldToDict(_ field: PassField) -> [String: Any] {
        var dict: [String: Any] = [
            "key": field.key,
            "value": field.value
        ]
        
        if let label = field.label {
            dict["label"] = label
        }
        if let textAlignment = field.textAlignment {
            dict["textAlignment"] = textAlignment
        }
        if let dateStyle = field.dateStyle {
            dict["dateStyle"] = dateStyle
        }
        if let timeStyle = field.timeStyle {
            dict["timeStyle"] = timeStyle
        }
        if let numberStyle = field.numberStyle {
            dict["numberStyle"] = numberStyle
        }
        if let currencyCode = field.currencyCode {
            dict["currencyCode"] = currencyCode
        }
        if let changeMessage = field.changeMessage {
            dict["changeMessage"] = changeMessage
        }
        
        return dict
    }
    
    /// Request pass generation from CloudFlare Worker (Generic format)
    private func requestGenericPassGeneration(payload: GenericPassPayload) async throws -> Data {
        // Log the payload being sent to server
        print("📤 Sending Generic pass generation request to server")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📋 Generic Pass Payload Details:")
        print("  • Pass Type: \(payload.passTypeIdentifier)")
        print("  • Serial Number: \(payload.serialNumber)")
        print("  • Organization: \(payload.organizationName)")
        print("  • Description: \(payload.description)")
        print("  • Logo Text: \(payload.logoText ?? "None")")
        print("  • Barcode Message: \(payload.barcodeMessage)")
        print("  • Barcode Format: \(payload.barcodeFormat)")
        print("  • Foreground Color: \(payload.foregroundColor)")
        print("  • Background Color: \(payload.backgroundColor)")
        print("  • Label Color: \(payload.labelColor ?? "None")")
        print("  • Header Fields: \(payload.headerFields.count)")
        print("  • Primary Fields: \(payload.primaryFields.count)")
        print("  • Secondary Fields: \(payload.secondaryFields.count)")
        print("  • Auxiliary Fields: \(payload.auxiliaryFields.count)")
        print("  • Back Fields: \(payload.backFields.count)")
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

    // MARK: - Wallet Library

    /// Returns true if a pass with the given identifiers currently exists in Apple Wallet.
    static func isPassInWallet(serialNumber: String, passTypeIdentifier: String) -> Bool {
        guard PKPassLibrary.isPassLibraryAvailable() else { return false }
        return PKPassLibrary().pass(
            withPassTypeIdentifier: passTypeIdentifier,
            serialNumber: serialNumber
        ) != nil
    }

    /// Removes a pass from Apple Wallet if it exists.
    static func removePassFromWallet(serialNumber: String, passTypeIdentifier: String) {
        guard PKPassLibrary.isPassLibraryAvailable() else { return }
        let library = PKPassLibrary()
        if let pass = library.pass(
            withPassTypeIdentifier: passTypeIdentifier,
            serialNumber: serialNumber
        ) {
            library.removePass(pass)
        }
    }
}

// MARK: - Pass Payload Structures

/// Payload for Apple PassKit Generic pass format
/// This structure matches the pass.json format required by Apple Wallet
struct GenericPassPayload: Codable {
    // MARK: - Required Pass Metadata
    let formatVersion: Int
    let passTypeIdentifier: String
    let serialNumber: String
    let teamIdentifier: String
    let organizationName: String
    let description: String
    let logoText: String?

    // MARK: - Pass Style
    /// Explicit pass style: "generic" | "storeCard" | "coupon" | "eventTicket"
    let passStyle: String

    // MARK: - Barcode
    let barcodeMessage: String
    let barcodeFormat: String
    let barcodeMessageEncoding: String

    // MARK: - Visual Design
    let foregroundColor: String
    let backgroundColor: String
    let labelColor: String?

    // MARK: - Generic Pass Fields
    let headerFields: [PassField]
    let primaryFields: [PassField]
    let secondaryFields: [PassField]
    let auxiliaryFields: [PassField]
    let backFields: [PassField]

    // MARK: - Images
    let logoImageData: Data?
    let bannerImageData: Data?

    // MARK: - Dates
    let expirationDate: String?
    let relevantDate: String?
}

/// Legacy payload structure for backward compatibility
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
    func addPassToWallet(
        passData: Data?,
        onSuccess: @escaping () -> Void,
        onError: @escaping (Error) -> Void,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.background(
            PassKitRepresentable(
                passData: passData,
                onSuccess: onSuccess,
                onError: onError,
                onDismiss: onDismiss
            )
        )
    }
}

struct PassKitRepresentable: UIViewControllerRepresentable {
    let passData: Data?
    let onSuccess: () -> Void
    let onError: (Error) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let passData = passData else {
            // passData cleared — reset so the next trigger can present again.
            context.coordinator.presented = false
            return
        }
        // Only present once per trigger (prevents re-presentation on SwiftUI redraws).
        guard !context.coordinator.presented else { return }
        guard uiViewController.presentedViewController == nil else { return }

        context.coordinator.presented = true

        do {
            let passKitIntegrator = PassKitIntegrator()
            if let addPassVC = try passKitIntegrator.addPassToWallet(passData: passData) {
                context.coordinator.addedPass = try? PKPass(data: passData)
                addPassVC.delegate = context.coordinator

                DispatchQueue.main.async {
                    uiViewController.present(addPassVC, animated: true)
                }
            }
        } catch {
            context.coordinator.presented = false
            onError(error)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(onSuccess: onSuccess, onError: onError, onDismiss: onDismiss)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onSuccess: () -> Void
        let onError: (Error) -> Void
        let onDismiss: () -> Void
        /// Prevents re-presentation on SwiftUI redraws while the sheet is active.
        var presented: Bool = false
        /// Holds the real PKPass so we can verify it landed in the library.
        var addedPass: PKPass?

        init(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void, onDismiss: @escaping () -> Void) {
            self.onSuccess = onSuccess
            self.onError = onError
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) {
                if let pass = self.addedPass, PKPassLibrary.isPassLibraryAvailable() {
                    // Small delay to let PassKit finish writing to the library.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let library = PKPassLibrary()
                        if library.pass(withPassTypeIdentifier: pass.passTypeIdentifier,
                                        serialNumber: pass.serialNumber) != nil {
                            self.onSuccess()
                        }
                        // Reset trigger state whether the user added or cancelled.
                        self.onDismiss()
                    }
                } else {
                    // No PKPass reference — call success as fallback, then reset.
                    self.onSuccess()
                    self.onDismiss()
                }
            }
        }
    }
}
