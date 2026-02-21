//
//  RootView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
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
