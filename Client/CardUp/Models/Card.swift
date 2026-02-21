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

@Model
final class Card {
    var id: UUID
    var passType: String
    var extractedTextJson: String
    var barcodeString: String
    var barcodeFormat: String
    var dominantColorsHex: [String]
    var logoImageData: Data?
    var bannerImageData: Data?
    var pkpassData: Data?
    var isDraft: Bool
    var isAddedToWallet: Bool
    var creationDate: Date
    
    init(
        id: UUID = UUID(),
        passType: String = "storeCard",
        extractedTextJson: String = "",
        barcodeString: String = "",
        barcodeFormat: String = "",
        dominantColorsHex: [String] = [],
        logoImageData: Data? = nil,
        bannerImageData: Data? = nil,
        pkpassData: Data? = nil,
        isDraft: Bool = true,
        isAddedToWallet: Bool = false,
        creationDate: Date = Date()
    ) {
        self.id = id
        self.passType = passType
        self.extractedTextJson = extractedTextJson
        self.barcodeString = barcodeString
        self.barcodeFormat = barcodeFormat
        self.dominantColorsHex = dominantColorsHex
        self.logoImageData = logoImageData
        self.bannerImageData = bannerImageData
        self.pkpassData = pkpassData
        self.isDraft = isDraft
        self.isAddedToWallet = isAddedToWallet
        self.creationDate = creationDate
    }
}

// MARK: - Computed Properties
extension Card {
    var extractedData: CardData? {
        guard let data = extractedTextJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CardData.self, from: data)
    }
    
    var primaryColor: Color {
        guard !dominantColorsHex.isEmpty,
              let firstHex = dominantColorsHex.first,
              !firstHex.isEmpty else { 
            return .blue 
        }
        return Color(hexString: firstHex) ?? .blue
    }
    
    var logoImage: UIImage? {
        guard let data = logoImageData else { return nil }
        return UIImage(data: data)
    }
    
    var bannerImage: UIImage? {
        guard let data = bannerImageData else { return nil }
        return UIImage(data: data)
    }
    
    var hasValidPass: Bool {
        return pkpassData != nil && !isDraft
    }
    
    var displayName: String {
        return extractedData?.cardName ?? extractedData?.companyName ?? "Loyalty Card"
    }
}

// MARK: - Supporting Types

/// Simple data structure for persisted card data (separate from Foundation Models)
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

