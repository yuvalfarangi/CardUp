//
//  Profile.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI

struct Profile: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthenticationService()
    @State private var paymentService = PaymentService()
    @State private var showSubscriptionSheet = false
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // User Profile Section
                    ProfileHeaderView(user: authService.currentUser)
                    
                    // Subscription Section
                    SubscriptionStatusView(
                        hasProAccess: paymentService.hasProAccess,
                        subscriptionType: authService.currentUser?.subscriptionType ?? .free,
                        onUpgrade: { showSubscriptionSheet = true }
                    )
                    
                    // Actions Section
                    VStack(spacing: 16) {
                        // Restore Purchases
                        Button("Restore Purchases") {
                            Task {
                                await paymentService.restorePurchases()
                            }
                        }
                        .buttonStyle(SecondaryGlassButtonStyle())
                        .disabled(paymentService.isLoading)
                        
                        // Sign Out
                        Button("Sign Out") {
                            showSignOutAlert = true
                        }
                        .buttonStyle(DestructiveGlassButtonStyle())
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionSheet(paymentService: paymentService)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authService.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out? Your cards will remain safe in iCloud.")
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .frame(width: 120, height: 120)
                .glassEffect(.regular, in: .rect(cornerRadius: 32))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
            
            // User Information
            VStack(spacing: 8) {
                Text(user?.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Subscription Status

struct SubscriptionStatusView: View {
    let hasProAccess: Bool
    let subscriptionType: SubscriptionType
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Subscription")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
            
            // Subscription Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(subscriptionType.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if hasProAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                if !hasProAccess {
                    Button("Upgrade to Pro") {
                        onUpgrade()
                    }
                    .buttonStyle(PrimaryGlassButtonStyle())
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Subscription Sheet

struct SubscriptionSheet: View {
    @Bindable var paymentService: PaymentService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 64))
                        
                        Text("Upgrade to Pro")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Unlock unlimited cards and premium features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Features
                    VStack(spacing: 16) {
                        ProFeatureRow(icon: "infinity", title: "Unlimited Cards", description: "Create as many wallet passes as you need")
                        ProFeatureRow(icon: "sparkles", title: "Premium Graphics", description: "Enhanced logo detection and graphics generation")
                        ProFeatureRow(icon: "icloud", title: "iCloud Sync", description: "Sync your cards across all your devices")
                        ProFeatureRow(icon: "brain.fill", title: "Advanced AI", description: "Better text extraction and pass optimization")
                    }
                    .padding(.horizontal, 32)
                    
                    // Subscription Options
                    if paymentService.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            if let yearlyProduct = paymentService.yearlyProduct {
                                SubscriptionButton(
                                    title: "Annual",
                                    price: paymentService.getDisplayPrice(for: yearlyProduct),
                                    period: paymentService.getSubscriptionPeriod(for: yearlyProduct),
                                    isRecommended: true
                                ) {
                                    Task {
                                        try await paymentService.purchase(product: yearlyProduct)
                                        dismiss()
                                    }
                                }
                            }
                            
                            if let monthlyProduct = paymentService.monthlyProduct {
                                SubscriptionButton(
                                    title: "Monthly",
                                    price: paymentService.getDisplayPrice(for: monthlyProduct),
                                    period: paymentService.getSubscriptionPeriod(for: monthlyProduct),
                                    isRecommended: false
                                ) {
                                    Task {
                                        try await paymentService.purchase(product: monthlyProduct)
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button("Terms") { }
                            Button("Privacy") { }
                            Button("Restore") {
                                Task {
                                    await paymentService.restorePurchases()
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Maybe Later") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
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

struct SubscriptionButton: View {
    let title: String
    let price: String
    let period: String
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if isRecommended {
                            Text("BEST VALUE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                        }
                    }
                    
                    Text("\(price) \(period)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Subscribe")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .overlay {
                if isRecommended {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.blue, lineWidth: 2)
                }
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Button Styles

struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .glassEffect(.regular.tint(.blue).interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DestructiveGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.regularMaterial, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    Profile()
}