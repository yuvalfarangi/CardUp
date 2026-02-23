//
//  HomeScreen.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.creationDate, order: .reverse) private var allCards: [Card]
    
    @State private var searchText = ""
    @State private var showAddCard = false
    @State private var showProfile = false
    
    // Computed properties for filtered cards
    private var walletCards: [Card] {
        allCards.filter { !$0.isDraft }
    }
    
    private var draftCards: [Card] {
        allCards.filter { $0.isDraft }
    }
    
    // Search functionality
    private var filteredWalletCards: [Card] {
        if searchText.isEmpty {
            return walletCards
        }
        return walletCards.filter { card in
            card.passDescription.localizedCaseInsensitiveContains(searchText) ||
            card.organizationName.localizedCaseInsensitiveContains(searchText) ||
            card.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredDraftCards: [Card] {
        if searchText.isEmpty {
            return draftCards
        }
        return draftCards.filter { card in
            card.passDescription.localizedCaseInsensitiveContains(searchText) ||
            card.organizationName.localizedCaseInsensitiveContains(searchText) ||
            card.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Added to Wallet Section
                    if !filteredWalletCards.isEmpty {
                        CardSection(
                            title: "Added to Wallet",
                            cards: filteredWalletCards,
                            isWalletSection: true
                        )
                    }
                    
                    // Drafts Section
                    if !filteredDraftCards.isEmpty {
                        CardSection(
                            title: "Drafts",
                            cards: filteredDraftCards,
                            isWalletSection: false
                        )
                    }
                    
                    // Empty state
                    if allCards.isEmpty {
                        EmptyStateView()
                    }
                    
                    // Bottom padding for the fixed bottom bar
                    Spacer()
                        .frame(height: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .overlay(alignment: .bottom) {
                BottomActionBar(
                    searchText: $searchText,
                    showAddCard: $showAddCard
                )
            }
        }
        .navigationTitle("CardUp")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ProfileButton(showProfile: $showProfile)
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView()
        }
        .sheet(isPresented: $showProfile) {
            Profile()
        }
    }
}

// MARK: - Card Section
struct CardSection: View {
    let title: String
    let cards: [Card]
    let isWalletSection: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(cards.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            LazyVStack(spacing: 12) {
                ForEach(cards) { card in
                    CardRowView(card: card, isWalletSection: isWalletSection)
                }
            }
        }
    }
}

// MARK: - Card Row View
struct CardRowView: View {
    let card: Card
    let isWalletSection: Bool
    
    @State private var showEditCard = false
    
    var body: some View {
        Button {
            if !isWalletSection {
                showEditCard = true
            }
            // For wallet cards, you might want different behavior
        } label: {
            HStack(spacing: 16) {
                // Card preview with gradient background
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardGradient)
                    .frame(width: 72, height: 45)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.passDescription ?? "Untitled Card")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    
                    Text(card.creationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // Status indicator
                VStack(spacing: 4) {
                    Image(systemName: isWalletSection ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.title3)
                        .foregroundColor(isWalletSection ? .green : .orange)
                    
                    if !isWalletSection {
                        Text("Draft")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CardButtonStyle())
        .sheet(isPresented: $showEditCard) {
            EditCardView(card: card) {
                // On save callback
                showEditCard = false
            }
        }
    }
    
    private var cardGradient: LinearGradient {
        guard !card.dominantColorsHex.isEmpty else {
            return LinearGradient(
                colors: [.blue, .blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        let colors = card.dominantColorsHex.compactMap { hexString -> Color? in
            guard !hexString.isEmpty else { return nil }
            return Color(hexString: hexString)
        }
        
        if colors.count >= 2 {
            return LinearGradient(
                colors: colors.prefix(3).map { $0 },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let color = colors.first {
            return LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.blue, .blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Profile Button
struct ProfileButton: View {
    @Binding var showProfile: Bool
    
    var body: some View {
        Button {
            showProfile = true
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    @Binding var searchText: String
    @Binding var showAddCard: Bool
    
    var body: some View {
        GlassEffectContainer(spacing: 20.0) {
            HStack(spacing: 16) {
                // Liquid Glass Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.body)
                    
                    TextField("Search cards...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.clear)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 25))
                
                // Add Card FAB
                Button {
                    showAddCard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .background(.blue)
                .clipShape(Circle())
                .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34) // Account for safe area
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Cards Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Tap the + button below to add your first card")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Card Button Style
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Placeholder Views (AddCardView moved to separate file)

// EditCardView moved to separate file

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeScreen()
    }
    .modelContainer(for: Card.self, inMemory: true)
}
