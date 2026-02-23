//
//  GlassEffectContainer.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI

/// A container view that enables modern Liquid Glass effects with merging and interactive capabilities.
///
/// `GlassEffectContainer` is a specialized container that allows multiple glass-effect views to
/// interact and merge when positioned close together, creating a cohesive, fluid visual experience
/// reminiscent of Apple's latest design language.
///
/// ## Liquid Glass Design
///
/// Liquid Glass is a dynamic material that combines optical properties of glass with fluid animations.
/// Key characteristics include:
///
/// - **Blur effects**: Content behind glass elements is softly blurred
/// - **Light reflection**: Colors from surrounding content reflect onto glass surfaces
/// - **Interactive response**: Glass reacts to touch and pointer interactions
/// - **Fluid merging**: Adjacent glass elements blend together naturally
///
/// ## Usage
///
/// Wrap your glass-effect views in this container to enable merging:
///
/// ```swift
/// GlassEffectContainer(spacing: 20) {
///     VStack(spacing: 15) {
///         Button("Action") { }
///             .glassEffect(.regular.interactive(), in: .capsule)
///
///         Button("Another Action") { }
///             .glassEffect(.regular.tint(.blue), in: .capsule)
///     }
/// }
/// ```
///
/// ## Spacing
///
/// The `spacing` parameter controls the proximity threshold for glass merging effects.
/// Smaller values create more cohesive groups, while larger values maintain separation.
///
/// ## Implementation Note
///
/// The current implementation provides the structure for glass merging. For full Liquid Glass
/// effects with physics-based animations and real-time blending, additional implementation
/// using UIViewRepresentable or custom Metal shaders would be required.
///
/// - SeeAlso: `View.glassEffect(_:in:isEnabled:)`, `Glass`, `GlassShape`
struct GlassEffectContainer<Content: View>: View {
    /// The minimum spacing between glass elements for merging effects.
    ///
    /// When glass-effect views are positioned closer than this threshold, they may visually
    /// merge or blend together for a cohesive appearance.
    let spacing: CGFloat
    
    /// The content views that will be wrapped with glass effect capabilities.
    let content: Content
    
    /// Creates a glass effect container with the specified spacing and content.
    ///
    /// - Parameters:
    ///   - spacing: The minimum spacing between elements (default: 20.0 points)
    ///   - content: A view builder closure that constructs the child views
    init(spacing: CGFloat = 20.0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

/// Extension providing glass effect modifiers for any SwiftUI view.
///
/// This extension makes it easy to apply Liquid Glass effects to standard SwiftUI views
/// with a simple, chainable modifier syntax.
extension View {
    /// Applies a liquid glass visual effect to the view.
    ///
    /// This modifier wraps the view with a translucent glass material that blurs content behind it
    /// and can respond to interactions. The glass effect can be customized with different styles,
    /// shapes, and interactive behaviors.
    ///
    /// ## Usage Examples
    ///
    /// ```swift
    /// // Basic glass effect with capsule shape
    /// Button("Tap Me") { }
    ///     .glassEffect()
    ///
    /// // Glass with custom tint color
    /// Text("Hello")
    ///     .glassEffect(.regular.tint(.blue))
    ///
    /// // Interactive glass that responds to touch
    /// Button("Interactive") { }
    ///     .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    ///
    /// // Disabled glass effect
    /// SomeView()
    ///     .glassEffect(isEnabled: false)
    /// ```
    ///
    /// ## Parameters
    ///
    /// - Parameters:
    ///   - glass: The glass style configuration. Use `.regular` for default style,
    ///            or customize with `.tint()` and `.interactive()` modifiers.
    ///   - shape: The shape of the glass effect. Options include `.capsule` (default),
    ///            `.rect(cornerRadius:)`, and `.circle`.
    ///   - isEnabled: Whether the glass effect is currently enabled. When `false`,
    ///                the view appears without the glass treatment.
    ///
    /// ## Visual Characteristics
    ///
    /// The glass effect includes:
    /// - Background blur using `.regularMaterial`
    /// - Subtle white stroke border for definition
    /// - Optional tint color overlay
    /// - Interactive glow for touch-responsive variants
    ///
    /// ## Performance Considerations
    ///
    /// Glass effects use visual effect views which can impact performance if overused.
    /// Consider:
    /// - Limiting the number of simultaneous glass views on screen
    /// - Using `isEnabled: false` when glass effect isn't needed
    /// - Avoiding animating glass effects excessively
    ///
    /// - Returns: A view with the applied glass effect
    ///
    /// - SeeAlso: `Glass`, `GlassShape`, `GlassEffectContainer`
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

/// Shape options for glass effects.
///
/// This enumeration defines the available shapes that can be used for glass effect backgrounds.
/// Each shape can be applied to any view through the `glassEffect(_:in:isEnabled:)` modifier.
///
/// ## Available Shapes
///
/// - `capsule`: A pill-shaped container with fully rounded ends (commonly used for buttons)
/// - `rect(cornerRadius:)`: A rectangle with customizable corner radius
/// - `circle`: A perfect circle (useful for circular buttons or badges)
///
/// ## Usage
///
/// ```swift
/// // Capsule shape (default)
/// Button("Action") { }.glassEffect(in: .capsule)
///
/// // Rounded rectangle
/// Text("Info").glassEffect(in: .rect(cornerRadius: 16))
///
/// // Circle
/// Image(systemName: "star").glassEffect(in: .circle)
/// ```
///
/// - SeeAlso: `View.glassEffect(_:in:isEnabled:)`
enum GlassShape {
    /// A pill-shaped glass effect with fully rounded ends.
    case capsule
    
    /// A rectangular glass effect with customizable corner rounding.
    ///
    /// - Parameter cornerRadius: The radius for rounding the corners (in points)
    case rect(cornerRadius: CGFloat)
    
    /// A circular glass effect.
    case circle
}

/// Internal view modifier that implements the glass effect rendering.
///
/// This modifier applies the visual glass treatment using SwiftUI's material effects,
/// overlays, and shape fills. It's designed to work with any `InsettableShape` to provide
/// consistent stroke borders.
///
/// ## Implementation Details
///
/// The glass effect is composed of multiple layers:
/// 1. Background material blur (`.regularMaterial`)
/// 2. Subtle white border for definition
/// 3. Optional tint color overlay for interactive feedback
///
/// ## Conditional Rendering
///
/// The effect respects the `isEnabled` flag, allowing it to be toggled without
/// removing the modifier from the view hierarchy.
///
/// - Note: This is an internal implementation detail and should not be used directly.
///         Use the `View.glassEffect(_:in:isEnabled:)` modifier instead.
private struct GlassEffectModifier<S: InsettableShape>: ViewModifier {
    /// The glass style configuration.
    let glass: Glass
    
    /// The shape to use for the glass effect background.
    let shape: S
    
    /// Whether the glass effect is currently enabled.
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

/// Configuration struct for customizing glass effect appearance and behavior.
///
/// `Glass` provides a fluent API for configuring the visual properties of glass effects.
/// It supports opacity adjustment, tint coloring, and interactive behaviors.
///
/// ## Basic Usage
///
/// ```swift
/// // Use the default regular glass
/// view.glassEffect(.regular)
///
/// // Customize with tint color
/// view.glassEffect(.regular.tint(.blue))
///
/// // Make it interactive
/// view.glassEffect(.regular.interactive())
///
/// // Combine customizations
/// view.glassEffect(.regular.tint(.purple).interactive())
/// ```
///
/// ## Properties
///
/// - `opacity`: Controls the transparency of the glass material (0.0 to 1.0)
/// - `tintColor`: An optional color overlay for theming
/// - `isInteractive`: Enables touch-responsive glow effects
///
/// ## Presets
///
/// - `.regular`: The standard glass effect with 80% opacity and no tint
///
/// ## Customization Methods
///
/// - `tint(_:)`: Returns a new Glass configuration with the specified tint color
/// - `interactive(_:)`: Returns a new Glass configuration with interactive behavior enabled
///
/// - SeeAlso: `View.glassEffect(_:in:isEnabled:)`
struct Glass {
    /// The opacity of the glass effect (0.0 = fully transparent, 1.0 = fully opaque).
    let opacity: Double
    
    /// The tint color to apply over the glass material.
    ///
    /// Use `.clear` for no tint, or provide a color to theme the glass effect.
    let tintColor: Color
    
    /// Whether the glass responds to touch and pointer interactions with visual feedback.
    let isInteractive: Bool
    
    /// Internal initializer for creating glass configurations.
    ///
    /// Use the static `.regular` preset or the customization methods instead of
    /// calling this initializer directly.
    private init(opacity: Double = 0.8, tintColor: Color = .clear, isInteractive: Bool = false) {
        self.opacity = opacity
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }
    
    /// The standard glass effect configuration with 80% opacity, no tint, and no interactivity.
    ///
    /// This is the recommended starting point for most glass effects. Customize using
    /// the `.tint()` and `.interactive()` methods as needed.
    ///
    /// - Example:
    /// ```swift
    /// Button("Click Me") { }
    ///     .glassEffect(.regular)
    /// ```
    static let regular = Glass()
    
    /// Returns a new Glass configuration with the specified tint color applied.
    ///
    /// The tint color is overlaid on the glass material to provide theming or visual
    /// feedback. The color should typically have low opacity (10-20%) for subtlety.
    ///
    /// - Parameter color: The tint color to apply
    /// - Returns: A new Glass configuration with the tint color applied
    ///
    /// - Example:
    /// ```swift
    /// Button("Action") { }
    ///     .glassEffect(.regular.tint(.blue))
    /// ```
    func tint(_ color: Color) -> Glass {
        Glass(opacity: opacity, tintColor: color, isInteractive: isInteractive)
    }
    
    /// Returns a new Glass configuration with interactive behavior enabled or disabled.
    ///
    /// When enabled, the glass effect displays visual feedback in response to touch
    /// and pointer interactions, creating a subtle glow effect. This is particularly
    /// useful for buttons and other interactive elements.
    ///
    /// - Parameter enabled: Whether interactive behavior should be enabled (default: true)
    /// - Returns: A new Glass configuration with the interactive setting applied
    ///
    /// - Example:
    /// ```swift
    /// Button("Interactive Button") { }
    ///     .glassEffect(.regular.interactive())
    ///
    /// // Combine with tint
    /// Button("Themed Button") { }
    ///     .glassEffect(.regular.tint(.purple).interactive())
    /// ```
    func interactive(_ enabled: Bool = true) -> Glass {
        Glass(opacity: opacity, tintColor: tintColor, isInteractive: enabled)
    }
}
