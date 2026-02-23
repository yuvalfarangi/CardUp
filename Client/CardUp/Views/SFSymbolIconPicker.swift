//
//  SFSymbolIconPicker.swift
//  CardUp
//
//  Created by Yuval Farangi on 23/02/2026.
//

import SwiftUI

/// A native SF Symbol icon picker for selecting card logos
struct SFSymbolIconPicker: View {
    @Binding var selectedIcon: String?
    @Binding var selectedIconColor: Color
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory: IconCategory = .all
    
    // Categories for easier navigation
    enum IconCategory: String, CaseIterable {
        case all = "All"
        case business = "Business"
        case shopping = "Shopping"
        case food = "Food & Drink"
        case fitness = "Fitness"
        case entertainment = "Entertainment"
        case travel = "Travel"
        case communication = "Communication"
        case objects = "Objects"
        
        var icons: [String] {
            switch self {
            case .all:
                return IconCategory.allCases.filter { $0 != .all }.flatMap { $0.icons }
            case .business:
                return ["building.2.fill", "briefcase.fill", "chart.line.uptrend.xyaxis", "doc.text.fill", "folder.fill", "star.fill", "crown.fill", "medal.fill"]
            case .shopping:
                return ["cart.fill", "bag.fill", "creditcard.fill", "giftcard.fill", "storefront.fill", "tag.fill", "dollarsign.circle.fill", "basket.fill"]
            case .food:
                return ["cup.and.saucer.fill", "fork.knife", "wineglass.fill", "mug.fill", "birthday.cake.fill", "takeoutbag.and.cup.and.straw.fill", "carrot.fill", "leaf.fill"]
            case .fitness:
                return ["figure.run", "dumbbell.fill", "heart.fill", "drop.fill", "bolt.heart.fill", "figure.walk", "figure.yoga", "sportscourt.fill"]
            case .entertainment:
                return ["tv.fill", "music.note", "film.fill", "gamecontroller.fill", "ticket.fill", "theatermasks.fill", "paintpalette.fill", "books.vertical.fill"]
            case .travel:
                return ["airplane", "car.fill", "tram.fill", "ferry.fill", "bicycle", "globe", "location.fill", "map.fill"]
            case .communication:
                return ["envelope.fill", "phone.fill", "message.fill", "paperplane.fill", "megaphone.fill", "bell.fill", "at", "mic.fill"]
            case .objects:
                return ["key.fill", "lock.fill", "shield.fill", "clock.fill", "calendar", "bookmark.fill", "flag.fill", "photo.fill"]
            }
        }
    }
    
    var filteredIcons: [String] {
        let categoryIcons = selectedCategory.icons
        
        if searchText.isEmpty {
            return categoryIcons
        }
        
        return categoryIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search icons", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Category picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(IconCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                // Icon grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                        ForEach(filteredIcons, id: \.self) { iconName in
                            IconButton(
                                iconName: iconName,
                                iconColor: selectedIconColor,
                                isSelected: selectedIcon == iconName
                            ) {
                                selectedIcon = iconName
                            }
                        }
                    }
                    .padding(16)
                }
                
                Divider()
                
                // Color picker
                VStack(spacing: 12) {
                    HStack {
                        Text("Icon Color")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Circle()
                            .fill(selectedIconColor)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle().stroke(Color(.separator), lineWidth: 1)
                            }
                    }
                    
                    ColorPicker("Select color", selection: $selectedIconColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(.regularMaterial)
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedIcon == nil)
                }
            }
        }
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule().fill(.blue)
                    } else {
                        Capsule().fill(Color(.systemGray5))
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let iconName: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 70)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(iconColor)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue, lineWidth: 3)
                            .frame(height: 70)
                    }
                }
                
                Text(iconName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    SFSymbolIconPicker(
        selectedIcon: .constant("building.2.fill"),
        selectedIconColor: .constant(.blue)
    )
}
