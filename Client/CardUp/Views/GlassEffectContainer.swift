//
//  GlassEffectContainer.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI

/// A container view that enables Liquid Glass effects to merge and interact when positioned close together
struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    init(spacing: CGFloat = 20.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

/// Extension to add glass effect support to views
extension View {
    /// Applies a liquid glass effect to the view with a capsule shape
    /// - Parameters:
    ///   - glass: The glass style configuration
    ///   - shape: The shape type (use .capsule, .rect, etc.)
    ///   - isEnabled: Whether the effect is enabled
    func glassEffect(
        _ glass: Glass = .regular,
        in shape: GlassShape = .capsule,
        isEnabled: Bool = true
    ) -> some View {
        Group {
            switch shape {
            case .capsule:
                self.modifier(GlassEffectModifier(glass: glass, shape: Capsule(), isEnabled: isEnabled))
            case .rect(let cornerRadius):
                self.modifier(GlassEffectModifier(glass: glass, shape: RoundedRectangle(cornerRadius: cornerRadius), isEnabled: isEnabled))
            case .circle:
                self.modifier(GlassEffectModifier(glass: glass, shape: Circle(), isEnabled: isEnabled))
            }
        }
    }
}

/// Glass effect shape options
enum GlassShape {
    case capsule
    case rect(cornerRadius: CGFloat)
    case circle
}

/// View modifier that applies glass effect
private struct GlassEffectModifier<S: InsettableShape>: ViewModifier {
    let glass: Glass
    let shape: S
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(.regularMaterial)
                    .opacity(isEnabled ? glass.opacity : 0)
                    .overlay(
                        shape
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(
                // Interactive glow effect for interactive glass
                shape
                    .fill(glass.tintColor.opacity(glass.isInteractive ? 0.1 : 0))
                    .allowsHitTesting(false)
            )
    }
}

/// Configuration for glass effects
struct Glass {
    let opacity: Double
    let tintColor: Color
    let isInteractive: Bool
    
    private init(opacity: Double = 0.8, tintColor: Color = .clear, isInteractive: Bool = false) {
        self.opacity = opacity
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }
    
    /// Regular glass effect
    static let regular = Glass()
    
    /// Apply a tint color to the glass effect
    func tint(_ color: Color) -> Glass {
        Glass(opacity: opacity, tintColor: color, isInteractive: isInteractive)
    }
    
    /// Make the glass interactive (responds to touch/hover)
    func interactive(_ enabled: Bool = true) -> Glass {
        Glass(opacity: opacity, tintColor: tintColor, isInteractive: enabled)
    }
}
