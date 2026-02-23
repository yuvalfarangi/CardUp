//
//  RootView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData

/// The root view of the CardUp application that manages top-level navigation and authentication state.
///
/// `RootView` serves as the entry point for the app's view hierarchy and handles the primary navigation
/// flow based on the user's authentication status. It acts as a state machine with three main states:
///
/// ## Application States
///
/// 1. **Loading**: Displayed while the authentication service verifies the user's session
/// 2. **Authenticated**: Shows the main app interface (HomeScreen) wrapped in a NavigationStack
/// 3. **Unauthenticated**: Presents the entry/login screen for Sign in with Apple
///
/// ## State Management
///
/// The view observes an `AuthenticationService` instance to determine which state to display.
/// State transitions are automatically animated with smooth ease-in-out animations.
///
/// ## SwiftData Integration
///
/// `RootView` receives the SwiftData `ModelContext` from the environment and injects it into
/// the authentication service. This allows the service to persist user data and cards to the
/// local database and optionally sync with iCloud.
///
/// ## Architecture Pattern
///
/// This view follows the common iOS pattern of a "root router" that manages top-level navigation:
/// - Authentication check on launch
/// - Conditional rendering based on auth state
/// - Smooth transitions between states
///
/// ## Usage
///
/// `RootView` is instantiated once in the app's `@main` entry point and provided with a
/// `modelContainer`:
///
/// ```swift
/// @main
/// struct CardUpApp: App {
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///         }
///         .modelContainer(sharedModelContainer)
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// All state changes and view updates occur on the main thread thanks to SwiftUI's automatic
/// main actor isolation and the `@MainActor` annotation on `AuthenticationService`.
///
/// - Note: The view uses `@State` for the authentication service to ensure proper ownership
///         and observation in the SwiftUI lifecycle.
///
/// - SeeAlso: `AuthenticationService`, `HomeScreen`, `EntryScreen`
struct RootView: View {
    /// The SwiftData model context from the environment for data persistence.
    ///
    /// This context is injected from the app's model container and is used to read and write
    /// Card and User objects. It's passed to the authentication service to enable user persistence.
    @Environment(\.modelContext) private var modelContext
    
    /// The authentication service that manages user login state and Sign in with Apple.
    ///
    /// This service is owned by the view (via `@State`) and is observed for changes to
    /// authentication status. When the status changes, the view automatically re-renders
    /// to show the appropriate screen.
    @State private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if authService.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else if authService.isAuthenticated {
                // Main app interface
                NavigationStack {
                    HomeScreen()
                }
            } else {
                // Entry/authentication screen
                EntryScreen()
            }
        }
        .onAppear {
            authService.modelContext = modelContext
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.isLoading)
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .modelContainer(for: [Card.self, User.self], inMemory: true)
}
