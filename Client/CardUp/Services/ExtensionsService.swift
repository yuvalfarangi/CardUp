//
//  Extensions.swift
//  CardUp
//
//  Created by Yuval Farangi on 21/02/2026.
//

import SwiftUI

// MARK: - String Extensions

/// Extension to String that provides utility methods for text analysis and manipulation.
///
/// This extension adds functionality to determine text directionality, which is particularly
/// useful for internationalization and proper rendering of multilingual content.
extension String {
    /// Determines if the string contains primarily right-to-left text.
    ///
    /// This computed property analyzes the Unicode scalar values in the string to determine
    /// if the majority of characters belong to right-to-left writing systems such as Hebrew,
    /// Arabic, Syriac, and other RTL scripts.
    ///
    /// The property examines each Unicode scalar in the string and checks if it falls within
    /// known RTL Unicode ranges. If more than 50% of the characters are RTL characters, the
    /// string is considered to be right-to-left.
    ///
    /// - Returns: `true` if more than 50% of the characters are RTL characters, `false` otherwise.
    ///            Returns `false` for empty strings.
    ///
    /// - Note: The 50% threshold means that mixed-language text will be classified based on
    ///         which direction is dominant. This heuristic works well for most use cases but
    ///         may need adjustment for specific scenarios.
    ///
    /// - Example:
    /// ```swift
    /// let hebrewText = "שלום"
    /// print(hebrewText.isRightToLeft) // true
    ///
    /// let englishText = "Hello"
    /// print(englishText.isRightToLeft) // false
    ///
    /// let mixedText = "Hello שלום"
    /// print(mixedText.isRightToLeft) // depends on character count ratio
    /// ```
    var isRightToLeft: Bool {
        guard !isEmpty else { return false }
        
        /// An array of Unicode ranges that represent right-to-left writing systems.
        ///
        /// This array contains closed ranges of Unicode scalar values (code points) for
        /// various RTL scripts including:
        /// - Hebrew (U+0590 to U+05FF)
        /// - Arabic (U+0600 to U+06FF)
        /// - Syriac (U+0700 to U+074F)
        /// - Arabic Supplement (U+0750 to U+077F)
        /// - Thaana (U+0780 to U+07BF)
        /// - N'Ko (U+07C0 to U+07FF)
        /// - Samaritan (U+0800 to U+083F)
        /// - Mandaic (U+0840 to U+085F)
        /// - Arabic Extended-A (U+08A0 to U+08FF)
        /// - Arabic Presentation Forms-A (U+FB50 to U+FDFF)
        /// - Arabic Presentation Forms-B (U+FE70 to U+FEFF)
        let rtlRanges: [ClosedRange<UInt32>] = [
            0x0590...0x05FF, // Hebrew
            0x0600...0x06FF, // Arabic
            0x0700...0x074F, // Syriac
            0x0750...0x077F, // Arabic Supplement
            0x0780...0x07BF, // Thaana
            0x07C0...0x07FF, // N'Ko
            0x0800...0x083F, // Samaritan
            0x0840...0x085F, // Mandaic
            0x08A0...0x08FF, // Arabic Extended-A
            0xFB50...0xFDFF, // Arabic Presentation Forms-A
            0xFE70...0xFEFF  // Arabic Presentation Forms-B
        ]
        
        /// Counter for the number of RTL characters found in the string.
        ///
        /// This variable is incremented each time a Unicode scalar is found that matches
        /// one of the RTL Unicode ranges.
        var rtlCharCount = 0
        
        /// Counter for the total number of characters (Unicode scalars) in the string.
        ///
        /// This variable is incremented for every Unicode scalar in the string, regardless
        /// of whether it's an RTL character or not.
        var totalCharCount = 0
        
        // Iterate through each Unicode scalar in the string and count RTL characters
        for scalar in unicodeScalars {
            totalCharCount += 1
            if rtlRanges.contains(where: { $0.contains(scalar.value) }) {
                rtlCharCount += 1
            }
        }
        
        // If more than 50% of characters are RTL, consider the string RTL
        return totalCharCount > 0 && Double(rtlCharCount) / Double(totalCharCount) > 0.5
    }
}

// MARK: - Color Extensions

/// Extension to Color that provides utility methods for color conversion and manipulation.
///
/// This extension adds functionality to work with hexadecimal color representations,
/// allowing conversion between SwiftUI Color objects and hex string formats commonly
/// used in web development and design tools.
extension Color {
    /// Initializes a Color from a hexadecimal string representation.
    ///
    /// This failable initializer creates a SwiftUI Color from a hex string. The hex string
    /// can be provided with or without a leading "#" symbol and supports both 6-character
    /// RGB format and 8-character RGBA format.
    ///
    /// - Parameter hex: A hexadecimal color string. Supported formats include:
    ///   - "FF5733" or "#FF5733" (6 characters for RGB, alpha defaults to 1.0)
    ///   - "FF5733FF" or "#FF5733FF" (8 characters for RGBA)
    ///
    /// - Returns: A Color object if the hex string is valid, or `nil` if the string
    ///            cannot be parsed or doesn't match the expected format.
    ///
    /// - Note: The initializer is case-insensitive for hex characters (A-F).
    ///
    /// - Example:
    /// ```swift
    /// let redColor = Color(hexString: "#FF0000")
    /// let blueWithAlpha = Color(hexString: "0000FF80")
    /// let invalidColor = Color(hexString: "invalid") // returns nil
    /// ```
    init?(hexString hex: String) {
        /// The sanitized hex string with whitespace and "#" prefix removed.
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        /// The unsigned 64-bit integer representation of the parsed hex value.
        ///
        /// This variable stores the raw RGB or RGBA values as a single integer,
        /// which is then broken down into individual color components.
        var rgb: UInt64 = 0
        
        // Attempt to parse the hex string; return nil if parsing fails
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        /// The number of characters in the sanitized hex string.
        let length = hexSanitized.count
        
        /// The red, green, blue, and alpha color components as Double values (0.0 to 1.0).
        ///
        /// These values are extracted from the parsed hex integer and normalized to the
        /// range 0.0-1.0 for use with SwiftUI Color.
        let r, g, b, a: Double
        
        // Parse color components based on hex string length
        if length == 6 {
            // 6-character format: RRGGBB
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            // 8-character format: RRGGBBAA
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            // Invalid length, return nil
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    /// Converts a Color to a hexadecimal string representation.
    ///
    /// This method converts a SwiftUI Color object into a 6-character hex string
    /// representing the RGB values. The alpha channel is not included in the output.
    ///
    /// - Returns: A 6-character uppercase hex string (e.g., "FF5733") representing
    ///            the RGB values of the color. Returns "000000" if the color components
    ///            cannot be extracted.
    ///
    /// - Note: The returned string does not include a "#" prefix. Add it manually if needed.
    ///
    /// - Warning: This method uses UIColor for color component extraction, which means
    ///            it's designed for iOS/iPadOS. For macOS apps, consider using NSColor instead.
    ///
    /// - Example:
    /// ```swift
    /// let color = Color.red
    /// let hexString = color.toHex() // Returns "FF0000"
    ///
    /// let customColor = Color(red: 0.5, green: 0.75, blue: 1.0)
    /// let hexString2 = customColor.toHex() // Returns "80BFFF"
    /// ```
    func toHex() -> String {
        /// The color components array extracted from the UIColor's CGColor.
        ///
        /// This array contains the red, green, and blue values (and potentially alpha)
        /// as floating-point values between 0.0 and 1.0. If extraction fails, the
        /// function returns a default black color hex string.
        guard let components = UIColor(self).cgColor.components else {
            return "000000"
        }
        
        /// The red color component (0.0 to 1.0).
        let r = components[0]
        
        /// The green color component (0.0 to 1.0).
        ///
        /// Falls back to the red component if green is not available (grayscale colors).
        let g = components.count > 1 ? components[1] : components[0]
        
        /// The blue color component (0.0 to 1.0).
        ///
        /// Falls back to the red component if blue is not available (grayscale colors).
        let b = components.count > 2 ? components[2] : components[0]
        
        /// The combined RGB value as a single integer.
        ///
        /// This value is created by bit-shifting and combining the red, green, and blue
        /// components (each scaled to 0-255) into a single integer for hex conversion.
        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255)
        
        return String(format: "%06X", rgb)
    }
}
// MARK: - View Extensions

/// Extension to View that provides utility modifiers for enhanced visual effects.
extension View {
    /// Applies a glass effect to the view (placeholder implementation).
    ///
    /// This modifier provides a placeholder for the Liquid Glass effect. In a production
    /// environment, this would integrate with the actual Liquid Glass APIs available
    /// in the latest iOS versions.
    ///
    /// - Parameters:
    ///   - style: The style of glass effect to apply
    ///   - shape: The shape to apply the effect within
    ///
    /// - Returns: A view with the glass effect applied (currently returns self).
    func glassEffect<S: Shape>(_ style: Any, in shape: S) -> some View {
        // Placeholder implementation - in production, this would use actual Liquid Glass APIs
        return self
    }
}

