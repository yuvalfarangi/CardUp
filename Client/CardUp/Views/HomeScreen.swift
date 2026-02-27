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
        allCards.filter { $0.isAddedToWallet }
    }

    private var savedCards: [Card] {
        allCards.filter { !$0.isAddedToWallet }
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

    private var filteredSavedCards: [Card] {
        if searchText.isEmpty {
            return savedCards
        }
        return savedCards.filter { card in
            card.passDescription.localizedCaseInsensitiveContains(searchText) ||
            card.organizationName.localizedCaseInsensitiveContains(searchText) ||
            card.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 24) {
                    // In Wallet Section — only cards confirmed added to Apple Wallet
                    if !filteredWalletCards.isEmpty {
                        CardSection(
                            title: "In Wallet",
                            cards: filteredWalletCards,
                            isWalletSection: true,
                            onDelete: deleteCard
                        )
                    }

                    // Saved Section — cards not yet in wallet (drafts + processed)
                    if !filteredSavedCards.isEmpty {
                        CardSection(
                            title: "Saved",
                            cards: filteredSavedCards,
                            isWalletSection: false,
                            onDelete: deleteCard
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
        .onAppear {
            syncWalletStatus()
        }
    }

    // MARK: - Actions

    private func deleteCard(_ card: Card) {
        // If the card is in Apple Wallet, remove it from there first
        if card.isAddedToWallet {
            PassKitIntegrator.removePassFromWallet(
                serialNumber: card.serialNumber,
                passTypeIdentifier: card.passTypeIdentifier
            )
        }
        modelContext.delete(card)
        try? modelContext.save()
    }

    /// Sync wallet status — cards may have been removed from Apple Wallet externally
    private func syncWalletStatus() {
        var didChange = false
        for card in allCards where card.isAddedToWallet {
            if !PassKitIntegrator.isPassInWallet(
                serialNumber: card.serialNumber,
                passTypeIdentifier: card.passTypeIdentifier
            ) {
                card.isAddedToWallet = false
                didChange = true
            }
        }
        if didChange {
            try? modelContext.save()
        }
    }
}

// MARK: - Card Section
struct CardSection: View {
    let title: String
    let cards: [Card]
    let isWalletSection: Bool
    let onDelete: (Card) -> Void

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
                    SwipeToDeleteWrapper(onDelete: { onDelete(card) }) {
                        CardRowView(card: card, isWalletSection: isWalletSection)
                    }
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

// MARK: - Swipe to Delete Wrapper

struct SwipeToDeleteWrapper<Content: View>: View {
    let onDelete: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    private let revealWidth: CGFloat = 80
    private let threshold: CGFloat = 50

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed behind the card
            Button(action: performDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.body)
                    Text("Delete")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(width: revealWidth)
                .frame(maxHeight: .infinity)
            }
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(offset < -4 ? 1 : 0)

            // Card content slides on swipe
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { value in
                            let h = value.translation.width
                            let v = value.translation.height
                            // Only handle predominantly horizontal drags
                            guard abs(h) > abs(v) else { return }
                            if h < 0 {
                                offset = max(h, -revealWidth)
                            } else {
                                // Allow sliding back when already open
                                offset = min(offset + h * 0.5, 0)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                if value.translation.width < -threshold {
                                    offset = -revealWidth
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private func performDelete() {
        withAnimation(.easeIn(duration: 0.2)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDelete()
        }
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
