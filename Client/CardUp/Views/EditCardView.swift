//
//  EditCardView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData
import PassKit

struct EditCardView: View {
    let card: Card
    let onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var passKitIntegrator = PassKitIntegrator()
    
    // Card data fields
    @State private var cardName: String = ""
    @State private var companyName: String = ""
    @State private var membershipNumber: String = ""
    @State private var expirationDate: String = ""
    @State private var barcodeString: String = ""
    @State private var selectedPassType: String = "storeCard"
    
    // Additional Apple Wallet fields
    @State private var headerField: String = ""
    @State private var auxiliaryField1: String = ""
    @State private var auxiliaryField2: String = ""
    @State private var backField1: String = ""
    @State private var backField2: String = ""
    
    // UI state
    @State private var isRegenerating = false
    @State private var regenerationError: String?
    @State private var showRegenerateAlert = false
    @State private var showAddToWallet = false
    @State private var showImagePicker = false
    @State private var showCropper = false
    @State private var uncroppedImage: UIImage?
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedBackgroundImage: UIImage?
    @State private var isBannerImageRemoved = false
    @State private var customBackgroundColor: Color = .blue
    @State private var stripImageValidation: StripImageProcessor.ValidationResult?
    
    let passTypes = [
        ("storeCard", "Store Card", "For retail loyalty cards"),
        ("generic", "Generic", "For membership and gym cards"),
        ("coupon", "Coupon", "For discount cards"),
        ("eventTicket", "Event Ticket", "For event admission")
    ]
    
    init(card: Card, onSave: (() -> Void)? = nil) {
        self.card = card
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    PassPreviewSection(
                        card: card,
                        cardName: cardName,
                        companyName: companyName,
                        membershipNumber: membershipNumber,
                        expirationDate: expirationDate,
                        barcodeString: barcodeString,
                        headerField: headerField,
                        auxiliaryField1: auxiliaryField1,
                        auxiliaryField2: auxiliaryField2,
                        selectedBackgroundImage: selectedBackgroundImage,
                        isBannerImageRemoved: isBannerImageRemoved,
                        backgroundColor: customBackgroundColor
                    )
                    
                    PassCustomizationSection(
                        card: card,
                        selectedBackgroundImage: selectedBackgroundImage,
                        isBannerImageRemoved: isBannerImageRemoved,
                        customBackgroundColor: $customBackgroundColor,
                        stripImageValidation: stripImageValidation,
                        onSelectImage: {
                            showImagePicker = true
                        },
                        onRemoveImage: {
                            selectedBackgroundImage = nil
                            isBannerImageRemoved = true
                        }
                    )
                    
                    PassTypeSection(
                        selectedType: $selectedPassType,
                        passTypes: passTypes
                    )
                    
                    CardInformationSection(
                        cardName: $cardName,
                        companyName: $companyName,
                        headerField: $headerField,
                        membershipNumber: $membershipNumber,
                        expirationDate: $expirationDate,
                        auxiliaryField1: $auxiliaryField1,
                        auxiliaryField2: $auxiliaryField2,
                        barcodeString: $barcodeString,
                        backField1: $backField1,
                        backField2: $backField2
                    )
                    
                    ActionButtonsSection(
                        onRegeneratePass: handleRegeneratePass,
                        onAddToWallet: handleAddToWallet,
                        hasValidPass: card.pkpassData != nil,
                        isRegenerating: isRegenerating
                    )
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadCardData()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $uncroppedImage, sourceType: imagePickerSourceType)
        }
        .onChange(of: uncroppedImage) { oldValue, newValue in
            if newValue != nil {
                showCropper = true
            }
        }
        .sheet(isPresented: $showCropper) {
            if let imageToCrop = uncroppedImage {
                ImageCropperView(image: imageToCrop, aspectRatio: 1125.0 / 369.0) { croppedImage in
                    selectedBackgroundImage = croppedImage
                    isBannerImageRemoved = false
                    uncroppedImage = nil
                    showCropper = false
                }
            }
        }
        .onChange(of: selectedBackgroundImage) { oldValue, newValue in
            if let image = newValue {
                stripImageValidation = StripImageProcessor.validateStripImage(image)
            } else {
                stripImageValidation = nil
            }
        }
        .addPassToWallet(
            passData: showAddToWallet ? card.pkpassData : nil,
            onSuccess: handleWalletSuccess,
            onError: handleWalletError
        )
        .alert("Regeneration Error", isPresented: $showRegenerateAlert) {
            Button("OK") {
                regenerationError = nil
            }
        } message: {
            if let error = regenerationError {
                Text(error)
            }
        }
        .overlay {
            if isRegenerating {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Regenerating pass...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    private func loadCardData() {
        if let data = card.extractedData {
            cardName = data.cardName ?? ""
            companyName = data.companyName ?? ""
            membershipNumber = data.membershipNumber ?? ""
            expirationDate = data.expirationDate ?? ""
            barcodeString = data.barcodeString ?? ""
            
            if let additionalText = data.additionalText {
                headerField = additionalText.count > 0 ? additionalText[0] : ""
                auxiliaryField1 = additionalText.count > 1 ? additionalText[1] : ""
                auxiliaryField2 = additionalText.count > 2 ? additionalText[2] : ""
                backField1 = additionalText.count > 3 ? additionalText[3] : ""
                backField2 = additionalText.count > 4 ? additionalText[4] : ""
            }
        }
        selectedPassType = card.passType
        
        if !card.dominantColorsHex.isEmpty {
            if let firstColor = Color(hexString: card.dominantColorsHex[0]) {
                customBackgroundColor = firstColor
            }
        }
    }
    
    private func saveCard() {
        saveCardData()
        try? modelContext.save()
        onSave?()
        dismiss()
    }
    
    private func handleRegeneratePass() {
        Task {
            isRegenerating = true
            regenerationError = nil
            
            do {
                saveCardData()
                
                let extractedData = ExtractedCardData(
                    cardName: cardName.isEmpty ? nil : cardName,
                    companyName: companyName.isEmpty ? nil : companyName,
                    barcodeString: barcodeString.isEmpty ? nil : barcodeString,
                    barcodeFormat: card.barcodeFormat.isEmpty ? "Code128" : card.barcodeFormat,
                    logoDescription: card.extractedData?.logoDescription,
                    graphicDescription: card.extractedData?.graphicDescription,
                    expirationDate: expirationDate.isEmpty ? nil : expirationDate,
                    membershipNumber: membershipNumber.isEmpty ? nil : membershipNumber,
                    additionalText: card.extractedData?.additionalText
                )
                
                card.passType = selectedPassType
                
                let passData = try await passKitIntegrator.generateWalletPass(for: card, with: extractedData)
                
                await MainActor.run {
                    card.pkpassData = passData
                    card.isDraft = false
                    try? modelContext.save()
                    isRegenerating = false
                }
                
            } catch {
                await MainActor.run {
                    regenerationError = "Failed to regenerate pass: \(error.localizedDescription)"
                    showRegenerateAlert = true
                    isRegenerating = false
                }
            }
        }
    }
    
    private func saveCardData() {
        if isBannerImageRemoved {
            card.bannerImageData = nil
        } else if let newBackgroundImage = selectedBackgroundImage {
            card.bannerImageData = newBackgroundImage.jpegData(compressionQuality: 0.8)
        }
        
        var additionalTextArray: [String] = []
        if !headerField.isEmpty { additionalTextArray.append(headerField) }
        if !auxiliaryField1.isEmpty { additionalTextArray.append(auxiliaryField1) }
        if !auxiliaryField2.isEmpty { additionalTextArray.append(auxiliaryField2) }
        if !backField1.isEmpty { additionalTextArray.append(backField1) }
        if !backField2.isEmpty { additionalTextArray.append(backField2) }
        
        let updatedData = ExtractedCardData(
            cardName: cardName.isEmpty ? nil : cardName,
            companyName: companyName.isEmpty ? nil : companyName,
            barcodeString: barcodeString.isEmpty ? nil : barcodeString,
            barcodeFormat: card.barcodeFormat.isEmpty ? "Code128" : card.barcodeFormat,
            logoDescription: card.extractedData?.logoDescription,
            graphicDescription: card.extractedData?.graphicDescription,
            expirationDate: expirationDate.isEmpty ? nil : expirationDate,
            membershipNumber: membershipNumber.isEmpty ? nil : membershipNumber,
            additionalText: additionalTextArray.isEmpty ? nil : additionalTextArray
        )
        
        card.passType = selectedPassType
        
        var newColors = card.dominantColorsHex
        let selectedColorHex = customBackgroundColor.toHex()
        
        if let existingIndex = newColors.firstIndex(of: selectedColorHex) {
            newColors.remove(at: existingIndex)
        }
        newColors.insert(selectedColorHex, at: 0)
        card.dominantColorsHex = newColors
        
        if let encoded = try? JSONEncoder().encode(updatedData),
           let jsonString = String(data: encoded, encoding: .utf8) {
            card.extractedTextJson = jsonString
            card.barcodeString = barcodeString
        }
    }
    
    private func handleAddToWallet() {
        if let passData = card.pkpassData,
           let jsonObject = try? JSONSerialization.jsonObject(with: passData) as? [String: Any],
           jsonObject["_mock"] as? Bool == true {
            regenerationError = "Development Mode: Configure your CloudFlare Worker to enable Apple Wallet integration. Pass data is saved locally."
            showRegenerateAlert = true
            return
        }
        showAddToWallet = true
    }
    
    private func handleWalletSuccess() {
        card.isAddedToWallet = true
        card.isDraft = false
        try? modelContext.save()
        onSave?()
        dismiss()
    }
    
    private func handleWalletError(_ error: Error) {
        print("Failed to add to wallet: \(error)")
    }
}

// MARK: - Pass Preview Section

struct PassPreviewSection: View {
    let card: Card
    let cardName: String
    let companyName: String
    let membershipNumber: String
    let expirationDate: String
    let barcodeString: String
    let headerField: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let backgroundColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple Wallet Preview")
                .font(.title3)
                .fontWeight(.semibold)
            
            GeometryReader { geometry in
                let passWidth: CGFloat = min(geometry.size.width, 375)
                let passHeight: CGFloat = passWidth * 1.256
                
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Group {
                            if let logoImage = card.logoImage {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                ZStack {
                                    Circle().fill(Color.white.opacity(0.3))
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .frame(width: 50, height: 50)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(companyName.isEmpty ? (card.extractedData?.companyName ?? "Company") : companyName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .environment(\.layoutDirection, 
                                    (companyName.isEmpty ? (card.extractedData?.companyName ?? "") : companyName).isRightToLeft ? .rightToLeft : .leftToRight)
                            
                            Text(cardName.isEmpty ? (card.extractedData?.cardName ?? "Loyalty Card") : cardName)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                                .environment(\.layoutDirection,
                                    (cardName.isEmpty ? (card.extractedData?.cardName ?? "") : cardName).isRightToLeft ? .rightToLeft : .leftToRight)
                        }
                        .padding(.top, 24)
                        
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .background(backgroundColor)
                    
                    Group {
                        if let stripImage = selectedBackgroundImage {
                            Image(uiImage: stripImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if !isBannerImageRemoved, let stripImage = card.bannerImage {
                            Image(uiImage: stripImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [backgroundColor, backgroundColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .frame(height: passHeight * 0.20)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        if !headerField.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("INFO")
                                    .font(.system(size: 11))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .tracking(0.5)
                                Text(headerField)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.primary)
                                    .environment(\.layoutDirection, headerField.isRightToLeft ? .rightToLeft : .leftToRight)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        }
                        
                        if !membershipNumber.isEmpty || card.extractedData?.membershipNumber != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MEMBER")
                                    .font(.system(size: 11))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .tracking(0.5)
                                Text(membershipNumber.isEmpty ? (card.extractedData?.membershipNumber ?? "") : membershipNumber)
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundColor(.primary)
                                    .environment(\.layoutDirection, 
                                        (membershipNumber.isEmpty ? (card.extractedData?.membershipNumber ?? "") : membershipNumber).isRightToLeft ? .rightToLeft : .leftToRight)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, headerField.isEmpty ? 20 : 8)
                            .padding(.bottom, 12)
                        }
                        
                        HStack(spacing: 40) {
                            if !expirationDate.isEmpty || card.extractedData?.expirationDate != nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EXPIRES")
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    Text(expirationDate.isEmpty ? (card.extractedData?.expirationDate ?? "") : expirationDate)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.primary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        
                        HStack(spacing: 40) {
                            if !auxiliaryField1.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("INFO")
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    Text(auxiliaryField1)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .environment(\.layoutDirection, auxiliaryField1.isRightToLeft ? .rightToLeft : .leftToRight)
                                }
                            }
                            if !auxiliaryField2.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("INFO")
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    Text(auxiliaryField2)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .environment(\.layoutDirection, auxiliaryField2.isRightToLeft ? .rightToLeft : .leftToRight)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        Spacer()
                        
                        let currentBarcodeString = barcodeString.isEmpty ? card.barcodeString : barcodeString
                        if !currentBarcodeString.isEmpty {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(.white)
                                    if card.barcodeFormat.lowercased().contains("qr") {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 60))
                                            .foregroundColor(.black)
                                    } else {
                                        HStack(spacing: 2) {
                                            ForEach(0..<20, id: \.self) { _ in
                                                Rectangle()
                                                    .fill(.black)
                                                    .frame(width: CGFloat.random(in: 1...4))
                                            }
                                        }
                                        .frame(height: 60)
                                    }
                                }
                                .frame(height: 80)
                                .padding(.horizontal, 20)
                                
                                Text(currentBarcodeString)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.primary)
                                    .tracking(1)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                }
                .frame(width: passWidth, height: passHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 450)
            
            HStack(spacing: 8) {
                Image(systemName: card.pkpassData != nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(card.pkpassData != nil ? .green : .orange)
                Text(card.pkpassData != nil ? "Pass ready for Wallet" : "Changes require pass regeneration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Pass Customization Section (Combined)

struct PassCustomizationSection: View {
    let card: Card
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    @Binding var customBackgroundColor: Color
    let stripImageValidation: StripImageProcessor.ValidationResult?
    let onSelectImage: () -> Void
    let onRemoveImage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pass Customization")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Customize the banner image and background color")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Card Color")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Detected from card")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(card.dominantColorsHex.enumerated()), id: \.offset) { index, hexColor in
                            if let color = Color(hexString: hexColor) {
                                ColorSelectionButton(
                                    color: color,
                                    isSelected: customBackgroundColor.toHex() == hexColor
                                ) {
                                    customBackgroundColor = color
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Circle()
                        .fill(customBackgroundColor)
                        .frame(width: 40, height: 40)
                        .shadow(color: customBackgroundColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    ColorPicker("Or choose custom color", selection: $customBackgroundColor, supportsOpacity: false)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            HStack {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                Text("AND")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Banner Image (Top Strip)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("1125×369")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                
                VStack(spacing: 12) {
                    let displayImage = selectedBackgroundImage ?? (isBannerImageRemoved ? nil : card.bannerImage)
                    
                    if let image = displayImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                                }
                            
                            Button(action: onRemoveImage) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                                    .padding(8)
                            }
                        }
                    } else {
                        Button(action: onSelectImage) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(height: 100)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 28))
                                            .foregroundColor(.blue)
                                        Text("Tap to add banner image")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("Recommended: 1125×369 pixels")
                                            .font(.caption2)
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: onSelectImage) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                            Text(displayImage == nil ? "Add Banner Image" : "Change Banner Image")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                if let validation = stripImageValidation {
                    HStack(spacing: 8) {
                        Image(systemName: validation.icon)
                            .foregroundColor(validation.color)
                        Text(validation.message)
                            .font(.caption2)
                            .foregroundColor(validation.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(validation.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Text("Note: The banner image appears in the strip area at the top of the pass. The card color is used for the header and overall pass background.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

// MARK: - ColorSelectionButton

struct ColorSelectionButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
                
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .stroke(color, lineWidth: 6)
                        .frame(width: 62, height: 62)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pass Type Section

struct PassTypeSection: View {
    @Binding var selectedType: String
    let passTypes: [(String, String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pass Type")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(passTypes, id: \.0) { type, title, description in
                    PassTypeRow(
                        type: type,
                        title: title,
                        description: description,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
        }
    }
}

struct PassTypeRow: View {
    let type: String
    let title: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .blue.opacity(0.1) : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card Information Section

struct CardInformationSection: View {
    @Binding var cardName: String
    @Binding var companyName: String
    @Binding var headerField: String
    @Binding var membershipNumber: String
    @Binding var expirationDate: String
    @Binding var auxiliaryField1: String
    @Binding var auxiliaryField2: String
    @Binding var barcodeString: String
    @Binding var backField1: String
    @Binding var backField2: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Card Information")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                FieldGroup(title: "Basic Information") {
                    EditField(title: "Card Name", text: $cardName, placeholder: "e.g., VIP Loyalty Card")
                    EditField(title: "Company", text: $companyName, placeholder: "e.g., Coffee Shop")
                }
                
                FieldGroup(title: "Front of Pass") {
                    EditField(title: "Header Field", text: $headerField, placeholder: "Optional header text")
                    EditField(title: "Membership Number", text: $membershipNumber, placeholder: "Member ID or account number")
                    EditField(title: "Expiration Date", text: $expirationDate, placeholder: "MM/YY (optional)")
                    EditField(title: "Auxiliary Info 1", text: $auxiliaryField1, placeholder: "Additional info (optional)")
                    EditField(title: "Auxiliary Info 2", text: $auxiliaryField2, placeholder: "Additional info (optional)")
                }
                
                FieldGroup(title: "Barcode/QR Code") {
                    EditField(title: "Barcode Data", text: $barcodeString, placeholder: "Barcode or QR code number")
                }
                
                FieldGroup(title: "Back of Pass") {
                    EditField(title: "Back Field 1", text: $backField1, placeholder: "Additional info for back (optional)")
                    EditField(title: "Back Field 2", text: $backField2, placeholder: "Additional info for back (optional)")
                }
            }
        }
    }
}

struct FieldGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            content()
        }
    }
}

// MARK: - Action Buttons Section

struct ActionButtonsSection: View {
    let onRegeneratePass: () -> Void
    let onAddToWallet: () -> Void
    let hasValidPass: Bool
    let isRegenerating: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if hasValidPass {
                Button(action: onAddToWallet) {
                    Label("Add to Wallet", systemImage: "wallet.pass.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .glassEffect(.regular.tint(.green).interactive(), in: .capsule)
                }
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                .disabled(isRegenerating)
            }
            
            Button(action: onRegeneratePass) {
                HStack(spacing: 8) {
                    if isRegenerating {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRegenerating ? "Regenerating..." : "Regenerate Pass")
                }
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.regularMaterial, in: Capsule())
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .disabled(isRegenerating)
        }
    }
}

// MARK: - Edit Field Component

struct EditField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                // Support both LTR and RTL text automatically
                .environment(\.layoutDirection, text.isRightToLeft ? .rightToLeft : .leftToRight)
                .multilineTextAlignment(text.isRightToLeft ? .trailing : .leading)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Cropper

struct ImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cropWidth = max(1, geometry.size.width - 40)
                let cropHeight = max(1, cropWidth / aspectRatio)
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = lastScale * value }
                                .onEnded { _ in lastScale = scale }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    
                    Rectangle()
                        .fill(.clear)
                        .frame(width: cropWidth, height: cropHeight)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2)
                        }
                    
                    VStack {
                        Spacer()
                        Text("Pinch to zoom • Drag to position")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                    }
                }
                .navigationTitle("Crop Banner Image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            executeCrop(geometry: geometry, cropWidth: cropWidth, cropHeight: cropHeight)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private func executeCrop(geometry: GeometryProxy, cropWidth: CGFloat, cropHeight: CGFloat) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropWidth, height: cropHeight), format: format)
        
        let croppedUIImage = renderer.image { _ in
            let imageAspect = image.size.width / image.size.height
            let viewAspect = geometry.size.width / geometry.size.height
            
            var drawWidth: CGFloat
            var drawHeight: CGFloat
            
            if imageAspect > viewAspect {
                drawWidth = geometry.size.width
                drawHeight = geometry.size.width / imageAspect
            } else {
                drawHeight = geometry.size.height
                drawWidth = geometry.size.height * imageAspect
            }
            
            drawWidth *= scale
            drawHeight *= scale
            
            let startX = (cropWidth - drawWidth) / 2 + offset.width
            let startY = (cropHeight - drawHeight) / 2 + offset.height
            
            image.draw(in: CGRect(x: startX, y: startY, width: drawWidth, height: drawHeight))
        }
        
        if let processedImage = StripImageProcessor.processStripImage(croppedUIImage, targetResolution: .threeX) {
            onCrop(processedImage)
        } else {
            onCrop(croppedUIImage)
        }
    }
}



