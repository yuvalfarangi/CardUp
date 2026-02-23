//
//  Card.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Color Hex Extension (inlined)
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Card model aligned with Apple PassKit Generic pass format
/// Stores all information needed to generate a .pkpass file compatible with Apple Wallet
@Model
final class Card {
    // MARK: - Core Identifiers
    
    /// Unique identifier for this card
    var id: UUID
    
    /// Pass type identifier (e.g., "pass.com.example.generic")
    /// This should match your Apple Developer account's Pass Type ID
    var passTypeIdentifier: String
    
    /// Unique serial number for this pass instance
    var serialNumber: String
    
    /// Creation timestamp
    var creationDate: Date
    
    // MARK: - Pass Metadata
    
    /// Organization name (e.g., "My Gym", "Coffee Shop")
    var organizationName: String
    
    /// Pass description (e.g., "Gym membership pass")
    var passDescription: String
    
    /// Text to display next to the logo (optional)
    var logoText: String?
    
    /// Pass format version (always 1 for current PassKit)
    var formatVersion: Int
    
    // MARK: - Visual Design
    
    /// Foreground color in hex format (e.g., "#FFFFFF")
    var foregroundColor: String
    
    /// Background color in hex format (e.g., "#F5C543")
    var backgroundColor: String
    
    /// Label color in hex format (optional, defaults to foregroundColor)
    var labelColor: String?
    
    /// Dominant colors extracted from card image for UI display
    var dominantColorsHex: [String]
    
    // MARK: - Barcode Information
    
    /// Barcode message/data (e.g., "12345678")
    var barcodeMessage: String
    
    /// Barcode format (e.g., "PKBarcodeFormatQR", "PKBarcodeFormatCode128")
    var barcodeFormat: String
    
    /// Message encoding for barcode (typically "iso-8859-1")
    var barcodeMessageEncoding: String
    
    // MARK: - Generic Pass Fields (Apple PassKit Structure)
    
    /// JSON string containing primary fields array
    /// Format: [{"key": "memberName", "label": "Name", "value": "Maria Ruiz"}]
    var primaryFieldsJson: String
    
    /// JSON string containing secondary fields array
    var secondaryFieldsJson: String
    
    /// JSON string containing auxiliary fields array
    var auxiliaryFieldsJson: String
    
    /// JSON string containing back fields array
    var backFieldsJson: String
    
    /// JSON string containing header fields array (optional)
    var headerFieldsJson: String
    
    // MARK: - Images
    
    /// Logo image data (icon displayed on the pass)
    var logoImageData: Data?
    
    /// Banner/strip image data (background image for the pass)
    var bannerImageData: Data?
    
    // MARK: - Dates
    
    /// Expiration date in ISO 8601 format (optional)
    var expirationDate: String?
    
    /// Relevant date in ISO 8601 format (optional)
    /// Pass becomes relevant at this date/time
    var relevantDate: String?
    
    // MARK: - Pass Data
    
    /// Generated .pkpass file data ready for Apple Wallet
    var pkpassData: Data?
    
    // MARK: - Status Flags
    
    /// Whether this card is still a draft (not yet finalized)
    var isDraft: Bool
    
    /// Whether this card has been successfully added to Apple Wallet
    var isAddedToWallet: Bool
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        passTypeIdentifier: String = "pass.com.example.generic",
        serialNumber: String = UUID().uuidString,
        creationDate: Date = Date(),
        organizationName: String = "",
        passDescription: String = "",
        logoText: String? = nil,
        formatVersion: Int = 1,
        foregroundColor: String = "#FFFFFF",
        backgroundColor: String = "#3B82F6",
        labelColor: String? = nil,
        dominantColorsHex: [String] = [],
        barcodeMessage: String = "",
        barcodeFormat: String = "PKBarcodeFormatQR",
        barcodeMessageEncoding: String = "iso-8859-1",
        primaryFieldsJson: String = "[]",
        secondaryFieldsJson: String = "[]",
        auxiliaryFieldsJson: String = "[]",
        backFieldsJson: String = "[]",
        headerFieldsJson: String = "[]",
        logoImageData: Data? = nil,
        bannerImageData: Data? = nil,
        expirationDate: String? = nil,
        relevantDate: String? = nil,
        pkpassData: Data? = nil,
        isDraft: Bool = true,
        isAddedToWallet: Bool = false
    ) {
        self.id = id
        self.passTypeIdentifier = passTypeIdentifier
        self.serialNumber = serialNumber
        self.creationDate = creationDate
        self.organizationName = organizationName
        self.passDescription = passDescription
        self.logoText = logoText
        self.formatVersion = formatVersion
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.labelColor = labelColor
        self.dominantColorsHex = dominantColorsHex
        self.barcodeMessage = barcodeMessage
        self.barcodeFormat = barcodeFormat
        self.barcodeMessageEncoding = barcodeMessageEncoding
        self.primaryFieldsJson = primaryFieldsJson
        self.secondaryFieldsJson = secondaryFieldsJson
        self.auxiliaryFieldsJson = auxiliaryFieldsJson
        self.backFieldsJson = backFieldsJson
        self.headerFieldsJson = headerFieldsJson
        self.logoImageData = logoImageData
        self.bannerImageData = bannerImageData
        self.expirationDate = expirationDate
        self.relevantDate = relevantDate
        self.pkpassData = pkpassData
        self.isDraft = isDraft
        self.isAddedToWallet = isAddedToWallet
    }
}

// MARK: - Computed Properties
extension Card {
    /// Decode primary fields from JSON string
    var primaryFields: [PassField] {
        guard let data = primaryFieldsJson.data(using: .utf8),
              let fields = try? JSONDecoder().decode([PassField].self, from: data) else {
            return []
        }
        return fields
    }
    
    /// Decode secondary fields from JSON string
    var secondaryFields: [PassField] {
        guard let data = secondaryFieldsJson.data(using: .utf8),
              let fields = try? JSONDecoder().decode([PassField].self, from: data) else {
            return []
        }
        return fields
    }
    
    /// Decode auxiliary fields from JSON string
    var auxiliaryFields: [PassField] {
        guard let data = auxiliaryFieldsJson.data(using: .utf8),
              let fields = try? JSONDecoder().decode([PassField].self, from: data) else {
            return []
        }
        return fields
    }
    
    /// Decode back fields from JSON string
    var backFields: [PassField] {
        guard let data = backFieldsJson.data(using: .utf8),
              let fields = try? JSONDecoder().decode([PassField].self, from: data) else {
            return []
        }
        return fields
    }
    
    /// Decode header fields from JSON string
    var headerFields: [PassField] {
        guard let data = headerFieldsJson.data(using: .utf8),
              let fields = try? JSONDecoder().decode([PassField].self, from: data) else {
            return []
        }
        return fields
    }
    
    /// Primary color for UI display (from backgroundColor)
    var primaryColor: Color {
        return Color(hex: backgroundColor) ?? Color.blue
    }
    
    /// Foreground color as SwiftUI Color
    var foregroundUIColor: Color {
        return Color(hex: foregroundColor) ?? Color.white
    }
    
    /// Label color as SwiftUI Color (defaults to foreground if not set)
    var labelUIColor: Color {
        if let labelColor = labelColor {
            return Color(hex: labelColor) ?? foregroundUIColor
        }
        return foregroundUIColor
    }
    
    /// Logo image as UIImage
    var logoImage: UIImage? {
        guard let data = logoImageData else { return nil }
        return UIImage(data: data)
    }
    
    /// Banner image as UIImage
    var bannerImage: UIImage? {
        guard let data = bannerImageData else { return nil }
        return UIImage(data: data)
    }
    
    /// Whether this card has a valid generated pass
    var hasValidPass: Bool {
        return pkpassData != nil && !isDraft
    }
    
    /// Display name for the card (organization name or description)
    var displayName: String {
        if !organizationName.isEmpty {
            return organizationName
        }
        if !passDescription.isEmpty {
            return passDescription
        }
        return "Card"
    }
    
    /// Update fields from PassField arrays
    func updatePrimaryFields(_ fields: [PassField]) {
        if let jsonData = try? JSONEncoder().encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.primaryFieldsJson = jsonString
        }
    }
    
    func updateSecondaryFields(_ fields: [PassField]) {
        if let jsonData = try? JSONEncoder().encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.secondaryFieldsJson = jsonString
        }
    }
    
    func updateAuxiliaryFields(_ fields: [PassField]) {
        if let jsonData = try? JSONEncoder().encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.auxiliaryFieldsJson = jsonString
        }
    }
    
    func updateBackFields(_ fields: [PassField]) {
        if let jsonData = try? JSONEncoder().encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.backFieldsJson = jsonString
        }
    }
    
    func updateHeaderFields(_ fields: [PassField]) {
        if let jsonData = try? JSONEncoder().encode(fields),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.headerFieldsJson = jsonString
        }
    }
}

// MARK: - Supporting Types

/// PassKit field structure matching Apple's pass.json format
struct PassField: Codable, Equatable {
    var key: String
    var label: String?
    var value: String
    var textAlignment: String? // "PKTextAlignmentLeft", "PKTextAlignmentCenter", "PKTextAlignmentRight"
    var dateStyle: String? // "PKDateStyleShort", "PKDateStyleMedium", "PKDateStyleLong", etc.
    var timeStyle: String? // "PKDateStyleShort", "PKDateStyleMedium", etc.
    var numberStyle: String? // "PKNumberStyleDecimal", "PKNumberStylePercent", etc.
    var currencyCode: String? // ISO 4217 currency code (e.g., "USD")
    var changeMessage: String? // Message to display when value changes
    
    /// Initialize a simple text field
    init(key: String, label: String? = nil, value: String, textAlignment: String? = nil) {
        self.key = key
        self.label = label
        self.value = value
        self.textAlignment = textAlignment
    }
    
    /// Initialize a date field
    init(key: String, label: String? = nil, value: String, dateStyle: String, timeStyle: String? = nil) {
        self.key = key
        self.label = label
        self.value = value
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }
}

/// Legacy data structure for backward compatibility
/// This is kept to avoid breaking existing code that might reference it
struct CardData: Codable, Equatable {
    var cardName: String?
    var companyName: String?
    var barcodeString: String?
    var barcodeFormat: String?
    var logoDescription: String?
    var graphicDescription: String?
    var expirationDate: String?
    var membershipNumber: String?
    var additionalText: [String]?
}

