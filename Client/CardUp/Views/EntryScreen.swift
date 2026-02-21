//
//  EntryScreen.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct EntryScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authService = AuthenticationService()
    @State private var showError = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Hero Section
                VStack(spacing: 32) {
                    Spacer()
                    
                    // App Icon and Branding
                    VStack(spacing: 20) {
                        // App Icon
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7), .cyan.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 24))
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                            .overlay {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.white)
                                    .symbolEffect(.pulse, options: .repeating)
                            }
                        
                        // App Title and Tagline
                        VStack(spacing: 12) {
                            Text("CardUp")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Transform any loyalty card into Apple Wallet passes")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
                    
                    // Features List
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "camera.fill",
                            title: "Scan & Convert",
                            description: "Take a photo and create a digital pass"
                        )
                        
                        FeatureRow(
                            icon: "brain.fill",
                            title: "Apple Intelligence",
                            description: "AI-powered text extraction and formatting"
                        )
                        
                        FeatureRow(
                            icon: "wallet.pass.fill",
                            title: "Apple Wallet",
                            description: "Seamless integration with your wallet"
                        )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
                
                // Sign In Section
                VStack(spacing: 20) {
                    if authService.isLoading {
                        ProgressView("Signing in...")
                            .font(.headline)
                            .padding()
                    } else {
                        SignInWithAppleButton { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task {
                                await authService.handleAuthorization(result: result)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .clipShape(Capsule())
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 32)
                    }
                    
                    // Privacy Notice
                    Text("Your privacy is protected. We only use your Apple ID for authentication and don't store personal information.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 32)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.9),
                    .blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(authService.error ?? "Unknown error occurred")
        }
        .onChange(of: authService.error) { _, error in
            showError = error != nil
        }
        // Navigate to main app when authenticated
        .fullScreenCover(isPresented: $authService.isAuthenticated) {
            HomeScreen()
                .modelContainer(for: [Card.self, User.self])
        }
        #if DEBUG && targetEnvironment(simulator)
        .onAppear {
            // Development bypass for persistent simulator issues
            // Uncomment to bypass authentication during development
            /*
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("🚀 Development Mode: Bypassing Apple ID authentication")
                authService.currentUser = User(appleUserId: "dev-user-simulator")
                authService.isAuthenticated = true
            }
            */
        }
        #endif
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .overlay {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    EntryScreen()
}