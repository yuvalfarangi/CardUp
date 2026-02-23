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
    
    // Additional Apple Wallet fields
    @State private var headerField: String = ""
    @State private var auxiliaryField1: String = ""
    @State private var auxiliaryField2: String = ""
    
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
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .white
    @State private var stripImageValidation: StripImageProcessor.ValidationResult?
    @State private var showIconPicker = false
    @State private var selectedIconName: String? = "creditcard.fill"
    @State private var selectedIconColor: Color = .white
    
    init(card: Card, onSave: (() -> Void)? = nil) {
        self.card = card
        self.onSave = onSave
    }
    
    var body: some View {
        mainContent
    }
    
    private var mainContent: some View {
        navigationView
            .onAppear { loadCardData() }
            .sheet(isPresented: $showIconPicker) {
                SFSymbolIconPicker(selectedIcon: $selectedIconName, selectedIconColor: $selectedIconColor)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $uncroppedImage, sourceType: imagePickerSourceType)
            }
            .onChange(of: uncroppedImage) { _, newValue in
                if newValue != nil { showCropper = true }
            }
            .sheet(isPresented: $showCropper) {
                cropperSheet
            }
            .onChange(of: selectedBackgroundImage) { _, newValue in
                handleBackgroundImageChange(newValue)
            }
            .addPassToWallet(
                passData: showAddToWallet ? card.pkpassData : nil,
                onSuccess: handleWalletSuccess,
                onError: handleWalletError
            )
            .alert("Regeneration Error", isPresented: $showRegenerateAlert) {
                Button("OK") { regenerationError = nil }
            } message: {
                if let error = regenerationError { Text(error) }
            }
            .overlay {
                if isRegenerating {
                    regeneratingOverlay
                }
            }
    }
    
    private var navigationView: some View {
        NavigationStack {
            scrollContent
                .navigationTitle("Edit Card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { saveCard() }
                            .fontWeight(.semibold)
                    }
                }
        }
    }
    
    private var scrollContent: some View {
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
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    selectedIconName: selectedIconName ?? "creditcard.fill",
                    selectedIconColor: selectedIconColor
                )
                
                LogoIconSection(
                    selectedIconName: selectedIconName ?? "creditcard.fill",
                    selectedIconColor: selectedIconColor,
                    onSelectIcon: { showIconPicker = true }
                )
                
                PassCustomizationSection(
                    card: card,
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    primaryColor: $primaryColor,
                    secondaryColor: $secondaryColor,
                    stripImageValidation: stripImageValidation,
                    onSelectImage: { showImagePicker = true },
                    onRemoveImage: {
                        selectedBackgroundImage = nil
                        isBannerImageRemoved = true
                    }
                )
                
                CardInformationSection(
                    cardName: $cardName,
                    companyName: $companyName,
                    headerField: $headerField,
                    membershipNumber: $membershipNumber,
                    expirationDate: $expirationDate,
                    auxiliaryField1: $auxiliaryField1,
                    auxiliaryField2: $auxiliaryField2,
                    barcodeString: $barcodeString
                )
                
                ActionButtonsSection(
                    onRegeneratePass: handleRegeneratePass,
                    onAddToWallet: handleAddToWallet,
                    hasValidPass: card.hasValidPass,
                    isRegenerating: isRegenerating
                )
                
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var cropperSheet: some View {
        if let imageToCrop = uncroppedImage {
            ImageCropperView(image: imageToCrop, aspectRatio: 1125.0 / 432.0) { croppedImage in
                selectedBackgroundImage = croppedImage
                isBannerImageRemoved = false
                uncroppedImage = nil
                showCropper = false
            }
        }
    }
    
    private var regeneratingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Regenerating pass...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private func handleBackgroundImageChange(_ newValue: UIImage?) {
        if let image = newValue {
            stripImageValidation = StripImageProcessor.validateStripImage(image)
        } else {
            stripImageValidation = nil
        }
    }
    
    private func loadCardData() {
        cardName = card.passDescription
        companyName = card.organizationName
        barcodeString = card.barcodeMessage
        expirationDate = card.expirationDate ?? ""
        
        headerField = card.headerFields.first?.value ?? ""
        membershipNumber = card.primaryFields.first?.value ?? ""
        
        let auxFields = card.auxiliaryFields
        auxiliaryField1 = auxFields.indices.contains(0) ? auxFields[0].value : ""
        auxiliaryField2 = auxFields.indices.contains(1) ? auxFields[1].value : ""
        
        primaryColor = card.primaryColor
        secondaryColor = card.foregroundUIColor
        
        // Load icon settings - use existing SF Symbol or default
        selectedIconName = card.logoSFSymbol ?? "creditcard.fill"
        selectedIconColor = card.logoColor
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
                
                var additionalTextArray: [String] = []
                if !headerField.isEmpty { additionalTextArray.append(headerField) }
                if !auxiliaryField1.isEmpty { additionalTextArray.append(auxiliaryField1) }
                if !auxiliaryField2.isEmpty { additionalTextArray.append(auxiliaryField2) }
                
                let extractedData = ExtractedCardData(
                    cardName: cardName.isEmpty ? nil : cardName,
                    companyName: companyName.isEmpty ? nil : companyName,
                    barcodeString: barcodeString.isEmpty ? nil : barcodeString,
                    barcodeFormat: card.barcodeFormat.isEmpty ? "Code128" : card.barcodeFormat,
                    logoDescription: nil,
                    graphicDescription: nil,
                    expirationDate: expirationDate.isEmpty ? nil : expirationDate,
                    membershipNumber: membershipNumber.isEmpty ? nil : membershipNumber,
                    additionalText: additionalTextArray.isEmpty ? nil : additionalTextArray
                )
                
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
        
        // Save SF Symbol icon settings (always save, never nil)
        card.logoSFSymbol = selectedIconName ?? "creditcard.fill"
        card.logoIconColor = selectedIconColor.toHex()
        card.logoImageData = nil // Always clear image data since we only use SF Symbols
        
        card.passDescription = cardName
        card.organizationName = companyName
        card.barcodeMessage = barcodeString
        card.expirationDate = expirationDate.isEmpty ? nil : expirationDate
        
        card.passTypeIdentifier = "pass.com.example.generic"
        
        var primary: [PassField] = []
        if !membershipNumber.isEmpty { primary.append(PassField(key: "membershipNumber", label: "Member", value: membershipNumber)) }
        card.updatePrimaryFields(primary)
        
        var headers: [PassField] = []
        if !headerField.isEmpty { headers.append(PassField(key: "header", label: "Info", value: headerField)) }
        card.updateHeaderFields(headers)
        
        var aux: [PassField] = []
        if !auxiliaryField1.isEmpty { aux.append(PassField(key: "aux1", label: "Info", value: auxiliaryField1)) }
        if !auxiliaryField2.isEmpty { aux.append(PassField(key: "aux2", label: "Info", value: auxiliaryField2)) }
        card.updateAuxiliaryFields(aux)
        
        let selectedPrimaryHex = primaryColor.toHex()
        var newColors = card.dominantColorsHex
        
        if let existingIndex = newColors.firstIndex(of: selectedPrimaryHex) {
            newColors.remove(at: existingIndex)
        }
        newColors.insert(selectedPrimaryHex, at: 0)
        card.dominantColorsHex = newColors
        card.backgroundColor = selectedPrimaryHex
        card.foregroundColor = secondaryColor.toHex()
        card.labelColor = secondaryColor.opacity(0.7).toHex()
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

// MARK: - Logo Icon Section

struct LogoIconSection: View {
    let selectedIconName: String
    let selectedIconColor: Color
    let onSelectIcon: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Logo Icon")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Choose an SF Symbol icon for your card logo")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                // Icon preview
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: selectedIconName)
                        .font(.system(size: 40))
                        .foregroundColor(selectedIconColor)
                }
                .overlay {
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: onSelectIcon) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("Change Icon")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Using SF Symbol: \(selectedIconName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    
    private var displayCompany: String {
        companyName.isEmpty ? (card.organizationName.isEmpty ? "Company" : card.organizationName) : companyName
    }
    
    private var displayCardName: String {
        cardName.isEmpty ? (card.passDescription.isEmpty ? "Loyalty Card" : card.passDescription) : cardName
    }
    
    private var displayMember: String {
        let fallbackMember = card.primaryFields.first?.value
        return membershipNumber.isEmpty ? (fallbackMember ?? "") : membershipNumber
    }
    
    private var currentBarcodeString: String {
        barcodeString.isEmpty ? card.barcodeMessage : barcodeString
    }
    
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
                        // Always display SF Symbol icon
                        ZStack {
                            Circle().fill(secondaryColor.opacity(0.3))
                            Image(systemName: selectedIconName)
                                .font(.system(size: 26))
                                .foregroundColor(selectedIconColor)
                        }
                        .frame(width: 50, height: 50)
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayCompany)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(secondaryColor)
                                .lineLimit(1)
                                .environment(\.layoutDirection, displayCompany.isRightToLeft ? .rightToLeft : .leftToRight)
                            
                            Text(displayCardName)
                                .font(.system(size: 13))
                                .foregroundColor(secondaryColor.opacity(0.9))
                                .lineLimit(1)
                                .environment(\.layoutDirection, displayCardName.isRightToLeft ? .rightToLeft : .leftToRight)
                        }
                        .padding(.top, 24)
                        
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .background(primaryColor)
                    
                    // Strip/Banner image section
                    // For Generic passes, this displays at approximately 20% of pass height
                    // Aspect ratio: 1125:432 (approximately 2.6:1)
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
                            // Fallback to gradient when no banner image is available
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [primaryColor, primaryColor.opacity(0.8)],
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
                                    .foregroundColor(secondaryColor.opacity(0.7))
                                    .tracking(0.5)
                                Text(headerField)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(secondaryColor)
                                    .environment(\.layoutDirection, headerField.isRightToLeft ? .rightToLeft : .leftToRight)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        }
                        
                        let fallbackMember = card.primaryFields.first?.value
                        if !membershipNumber.isEmpty || fallbackMember != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MEMBER")
                                    .font(.system(size: 11))
                                    .fontWeight(.medium)
                                    .foregroundColor(secondaryColor.opacity(0.7))
                                    .tracking(0.5)
                                
                                Text(displayMember)
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundColor(secondaryColor)
                                    .environment(\.layoutDirection, displayMember.isRightToLeft ? .rightToLeft : .leftToRight)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, headerField.isEmpty ? 20 : 8)
                            .padding(.bottom, 12)
                        }
                        
                        HStack(spacing: 40) {
                            if !expirationDate.isEmpty || card.expirationDate != nil {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("EXPIRES")
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(secondaryColor.opacity(0.7))
                                        .tracking(0.5)
                                    Text(expirationDate.isEmpty ? (card.expirationDate ?? "") : expirationDate)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(secondaryColor)
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
                                        .foregroundColor(secondaryColor.opacity(0.7))
                                        .tracking(0.5)
                                    Text(auxiliaryField1)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(secondaryColor)
                                        .lineLimit(1)
                                        .environment(\.layoutDirection, auxiliaryField1.isRightToLeft ? .rightToLeft : .leftToRight)
                                }
                            }
                            if !auxiliaryField2.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("INFO")
                                        .font(.system(size: 11))
                                        .fontWeight(.medium)
                                        .foregroundColor(secondaryColor.opacity(0.7))
                                        .tracking(0.5)
                                    Text(auxiliaryField2)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(secondaryColor)
                                        .lineLimit(1)
                                        .environment(\.layoutDirection, auxiliaryField2.isRightToLeft ? .rightToLeft : .leftToRight)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        Spacer()
                        
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
                                    .foregroundColor(secondaryColor)
                                    .tracking(1)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(primaryColor)
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
                Image(systemName: card.hasValidPass ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(card.hasValidPass ? .green : .orange)
                Text(card.hasValidPass ? "Pass ready for Wallet" : "Changes require pass regeneration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Pass Customization Section

struct PassCustomizationSection: View {
    let card: Card
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    @Binding var primaryColor: Color
    @Binding var secondaryColor: Color
    let stripImageValidation: StripImageProcessor.ValidationResult?
    let onSelectImage: () -> Void
    let onRemoveImage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pass Customization")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Customize the banner image and colors")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                ColorPickerGroup(
                    title: "Card Background Color",
                    dominantColorsHex: card.dominantColorsHex,
                    selectedColor: $primaryColor
                )
                ColorPickerGroup(
                    title: "Text & Fields Color",
                    dominantColorsHex: card.dominantColorsHex,
                    selectedColor: $secondaryColor
                )
            }
            
            HStack {
                Rectangle().fill(Color(.separator)).frame(height: 1)
                Text("AND")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle().fill(Color(.separator)).frame(height: 1)
            }
            .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Banner Image (Top Strip)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Updated dimensions for Apple PassKit Generic pass strip image
                    // The correct size is 1125 x 432 pixels (@3x resolution)
                    Text("1125×432")
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
                                        // Updated recommended dimensions for strip image
                                        Text("Recommended: 1125×432 pixels")
                                            .font(.caption2)
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: onSelectImage) {
                        HStack {
                            Image(systemName: "photo").foregroundColor(.blue)
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
            
            Text("Note: The banner image appears in the strip area at the top of the pass. The primary color is used for the pass background, and the secondary color is used for the text.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

// MARK: - Color Picker Group

struct ColorPickerGroup: View {
    let title: String
    let dominantColorsHex: [String]
    @Binding var selectedColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
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
                    ForEach(Array(dominantColorsHex.enumerated()), id: \.offset) { _, hexColor in
                        if let color = Color(hex: hexColor) {
                            ColorSelectionButton(
                                color: color,
                                isSelected: selectedColor.toHex() == hexColor
                            ) {
                                selectedColor = color
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            
            HStack {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 40, height: 40)
                    .shadow(color: selectedColor.opacity(0.4), radius: 4, x: 0, y: 2)
                
                ColorPicker("Or choose custom color", selection: $selectedColor, supportsOpacity: false)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                .disabled(isRegenerating)
            }
            
            Button(action: onRegeneratePass) {
                HStack(spacing: 8) {
                    if isRegenerating {
                        ProgressView().tint(.primary)
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
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        
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
