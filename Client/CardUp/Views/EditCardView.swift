//  EditCardView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData
import PassKit
import WebKit

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
    @State private var pendingWalletAdd = false
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
    @State private var selectedPassStyle: PassStyle = .generic
    @State private var selectedBarcodeFormat: String = "PKBarcodeFormatQR"

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
            .onChange(of: secondaryColor) { _, newValue in
                // Auto-sync icon color with secondary color (user can override in icon picker)
                selectedIconColor = newValue
            }
            .addPassToWallet(
                passData: showAddToWallet ? card.pkpassData : nil,
                onSuccess: handleWalletSuccess,
                onError: handleWalletError,
                onDismiss: { showAddToWallet = false }
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
                // Swipeable Pass Preview Section
                SwipeablePassPreviewSection(
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
                    selectedIconColor: selectedIconColor,
                    barcodeFormat: selectedBarcodeFormat,
                    selectedPassStyle: $selectedPassStyle,
                    onStyleChanged: handlePassStyleChange
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
                    passStyle: selectedPassStyle,
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
                    barcodeString: $barcodeString,
                    barcodeFormat: $selectedBarcodeFormat,
                    passStyle: selectedPassStyle
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
            .containerRelativeFrame(.horizontal)
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
        
        // Auto-sync icon color with secondary color (unless manually customized)
        // If the saved icon color matches the old foreground color, sync it
        selectedIconColor = card.logoColor
        
        // Load pass style
        selectedPassStyle = card.passStyleType

        // Load barcode format
        selectedBarcodeFormat = card.barcodeFormat.isEmpty ? "PKBarcodeFormatQR" : card.barcodeFormat
    }
    
    private func handlePassStyleChange(_ newStyle: PassStyle) {
        // Validate and trim fields based on new style's limits
        let limits = newStyle.fieldLimits
        
        // Trim header fields if exceeding limit
        var headers = card.headerFields
        if headers.count > limits.header {
            headers = Array(headers.prefix(limits.header))
            card.updateHeaderFields(headers)
            if limits.header == 0 {
                headerField = ""
            }
        }
        
        // Trim primary fields if exceeding limit  
        var primary = card.primaryFields
        if primary.count > limits.primary {
            primary = Array(primary.prefix(limits.primary))
            card.updatePrimaryFields(primary)
            if limits.primary == 0 {
                membershipNumber = ""
            }
        }
        
        // Trim auxiliary fields if exceeding limit
        var auxiliary = card.auxiliaryFields
        if auxiliary.count > limits.auxiliary {
            auxiliary = Array(auxiliary.prefix(limits.auxiliary))
            card.updateAuxiliaryFields(auxiliary)
            // Reset auxiliary fields that exceed the limit
            if limits.auxiliary < 2 {
                auxiliaryField2 = ""
            }
            if limits.auxiliary < 1 {
                auxiliaryField1 = ""
            }
        }
        
        // Handle image type changes
        if newStyle.supportsBackgroundImage && !newStyle.supportsStripImage {
            // Switching to event ticket - may need different image aspect ratio
            // Keep the existing image for now, user can replace it
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
                
                // First, request banner image generation from server
                let cardDesignRequest = CardDesignRequest(
                    organizationName: companyName.isEmpty ? nil : companyName,
                    description: cardName.isEmpty ? nil : cardName,
                    logoText: companyName.isEmpty ? nil : companyName,
                    backgroundColor: primaryColor.toHex(),
                    foregroundColor: secondaryColor.toHex(),
                    designStyle: nil,
                    additionalContext: nil
                )
                
                // Request the design from the server (optional, continues if fails)
                do {
                    print("🎨 Requesting banner design from server...")
                    let designResponse = try await ServerApi.shared.generateCardDesign(cardDetails: cardDesignRequest)
                    
                    print("📥 Received design response:")
                    print("  • Design Image length: \(designResponse.designImage.count) characters")
                    print("  • First 100 chars: \(String(designResponse.designImage.prefix(100)))")
                    print("  • Contains <svg: \(designResponse.designImage.contains("<svg"))")
                    print("  • Starts with 'data:': \(designResponse.designImage.hasPrefix("data:"))")
                    
                    // Convert SVG to PNG at 1125x432 pixels
                    if let bannerImage = await convertSVGToPNG(svgString: designResponse.designImage, width: 1125, height: 432) {
                        // Save the generated banner image to the card
                        await MainActor.run {
                            card.bannerImageData = bannerImage.jpegData(compressionQuality: 0.9)
                            selectedBackgroundImage = bannerImage
                            isBannerImageRemoved = false
                        }
                        print("✅ Banner image generated and saved successfully")
                    } else {
                        print("⚠️ Failed to convert SVG to image, using existing banner")
                    }
                } catch {
                    print("⚠️ Banner generation failed: \(error.localizedDescription). Continuing with existing banner.")
                    // Continue pass generation even if banner generation fails
                }
                
                var additionalTextArray: [String] = []
                if !headerField.isEmpty { additionalTextArray.append(headerField) }
                if !auxiliaryField1.isEmpty { additionalTextArray.append(auxiliaryField1) }
                if !auxiliaryField2.isEmpty { additionalTextArray.append(auxiliaryField2) }
                
                let extractedData = ExtractedCardData(
                    cardName: cardName.isEmpty ? nil : cardName,
                    companyName: companyName.isEmpty ? nil : companyName,
                    barcodeString: barcodeString.isEmpty ? nil : barcodeString,
                    barcodeFormat: selectedBarcodeFormat.isEmpty ? "PKBarcodeFormatCode128" : selectedBarcodeFormat,
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
                    if pendingWalletAdd {
                        pendingWalletAdd = false
                        showAddToWallet = true
                    }
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
    
    /// Converts an SVG string to a PNG UIImage at the specified dimensions
    /// - Parameters:
    ///   - svgString: The SVG code as a string
    ///   - width: Target width in pixels
    ///   - height: Target height in pixels
    /// - Returns: UIImage or nil if conversion fails
    private func convertSVGToPNG(svgString: String, width: CGFloat, height: CGFloat) async -> UIImage? {
        // Check if the string is actually SVG
        guard svgString.contains("<svg") else {
            // If it's a base64 image or URL, try to decode it
            if svgString.hasPrefix("data:image") {
                return decodeBase64Image(svgString)
            }
            print("⚠️ SVG string does not contain <svg> tag")
            return nil
        }
        
        print("🎨 Converting SVG to PNG at \(Int(width))x\(Int(height)) pixels...")
        
        // Create HTML wrapper for the SVG
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; }
                html, body {
                    width: \(width)px;
                    height: \(height)px;
                    overflow: hidden;
                }
                svg {
                    width: 100%;
                    height: 100%;
                    display: block;
                }
            </style>
        </head>
        <body>
            \(svgString)
        </body>
        </html>
        """
        
        // Use async/await with continuation for WebView rendering
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Create a WebKit WKWebView to render the SVG
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height))
                webView.isOpaque = false
                webView.backgroundColor = .clear
                
                // Load the HTML
                webView.loadHTMLString(htmlString, baseURL: nil)
                
                // Wait for rendering to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let config = WKSnapshotConfiguration()
                    config.rect = CGRect(x: 0, y: 0, width: width, height: height)
                    
                    webView.takeSnapshot(with: config) { image, error in
                        if let error = error {
                            print("❌ Failed to capture WebView snapshot: \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        } else if let image = image {
                            print("✅ Successfully converted SVG to PNG (\(Int(image.size.width))x\(Int(image.size.height)))")
                            continuation.resume(returning: image)
                        } else {
                            print("❌ No image captured from WebView")
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }
    }
    
    /// Decodes a base64 encoded image string
    /// - Parameter base64String: String in format "data:image/png;base64,..."
    /// - Returns: UIImage or nil if decoding fails
    private func decodeBase64Image(_ base64String: String) -> UIImage? {
        // Extract the base64 data portion
        let components = base64String.components(separatedBy: ",")
        guard components.count == 2 else {
            print("⚠️ Invalid base64 image string format")
            return nil
        }
        
        let base64Data = components[1]
        
        // Decode base64 string to Data
        guard let imageData = Data(base64Encoded: base64Data, options: .ignoreUnknownCharacters) else {
            print("❌ Failed to decode base64 image data")
            return nil
        }
        
        // Create UIImage from data
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from decoded data")
            return nil
        }
        
        print("✅ Successfully decoded base64 image (\(Int(image.size.width))x\(Int(image.size.height)))")
        return image
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
        card.barcodeFormat = selectedBarcodeFormat
        card.barcodeMessageEncoding = "iso-8859-1"
        card.expirationDate = expirationDate.isEmpty ? nil : expirationDate
        
        // Save the selected pass style
        card.updatePassStyle(selectedPassStyle)
        card.passTypeIdentifier = "pass.com.example.\(selectedPassStyle.rawValue)"
        
        // Apply field limits based on pass style
        let limits = selectedPassStyle.fieldLimits
        
        var primary: [PassField] = []
        if !membershipNumber.isEmpty && limits.primary > 0 {
            primary.append(PassField(key: "membershipNumber", label: "Member", value: membershipNumber))
        }
        card.updatePrimaryFields(Array(primary.prefix(limits.primary)))

        var headers: [PassField] = []
        if !headerField.isEmpty && limits.header > 0 {
            headers.append(PassField(key: "header", label: "Info", value: headerField))
        }
        card.updateHeaderFields(Array(headers.prefix(limits.header)))

        // Secondary fields: expiration date (makes it visible on the actual pass front)
        var secondary: [PassField] = []
        if !expirationDate.isEmpty {
            secondary.append(PassField(key: "expiry", label: "Expires", value: expirationDate))
        }
        card.updateSecondaryFields(secondary)

        var aux: [PassField] = []
        if !auxiliaryField1.isEmpty && limits.auxiliary > 0 {
            aux.append(PassField(key: "aux1", label: "Info", value: auxiliaryField1))
        }
        if !auxiliaryField2.isEmpty && limits.auxiliary > 1 {
            aux.append(PassField(key: "aux2", label: "Info", value: auxiliaryField2))
        }
        card.updateAuxiliaryFields(Array(aux.prefix(limits.auxiliary)))
        
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
        // Generate the .pkpass from the current edit-view state (no banner regeneration).
        // This ensures the pass type, colors, and fields always match what the user sees.
        Task {
            isRegenerating = true
            do {
                saveCardData()

                let extractedData = ExtractedCardData(
                    cardName: cardName.isEmpty ? nil : cardName,
                    companyName: companyName.isEmpty ? nil : companyName,
                    barcodeString: barcodeString.isEmpty ? nil : barcodeString,
                    barcodeFormat: selectedBarcodeFormat.isEmpty ? "PKBarcodeFormatCode128" : selectedBarcodeFormat,
                    logoDescription: nil,
                    graphicDescription: nil,
                    expirationDate: expirationDate.isEmpty ? nil : expirationDate,
                    membershipNumber: membershipNumber.isEmpty ? nil : membershipNumber,
                    additionalText: nil
                )

                let _ = try await passKitIntegrator.generateWalletPass(for: card, with: extractedData)

                await MainActor.run {
                    try? modelContext.save()
                    isRegenerating = false
                    showAddToWallet = true
                }
            } catch {
                await MainActor.run {
                    isRegenerating = false
                    regenerationError = "Failed to generate pass: \(error.localizedDescription)"
                    showRegenerateAlert = true
                }
            }
        }
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

// MARK: - Swipeable Pass Preview Section

struct SwipeablePassPreviewSection: View {
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
    let barcodeFormat: String
    @Binding var selectedPassStyle: PassStyle
    let onStyleChanged: (PassStyle) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentIndex: Int = 0
    
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
            // Title and instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple Wallet Preview")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Swipe the pass to change type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Swipeable pass preview
            GeometryReader { geometry in
                let passWidth: CGFloat = min(geometry.size.width, 375)
                let passHeight: CGFloat = passWidth * 1.256
                
                ZStack {
                    ForEach(Array(PassStyle.allCases.enumerated()), id: \.offset) { index, style in
                        passPreview(for: style, passWidth: passWidth, passHeight: passHeight)
                            .offset(x: CGFloat(index - currentIndex) * (passWidth + 20) + dragOffset)
                            .scaleEffect(index == currentIndex ? 1.0 : 0.9)
                            .opacity(index == currentIndex ? 1.0 : 0.4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
                    }
                }
                .frame(width: passWidth, height: passHeight)
                .clipped()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if value.translation.width < -threshold && currentIndex < PassStyle.allCases.count - 1 {
                                    currentIndex += 1
                                } else if value.translation.width > threshold && currentIndex > 0 {
                                    currentIndex -= 1
                                }
                                dragOffset = 0
                                
                                // Update selected style
                                selectedPassStyle = PassStyle.allCases[currentIndex]
                                onStyleChanged(selectedPassStyle)
                            }
                        }
                )
            }
            .frame(height: 480)
            
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(Array(PassStyle.allCases.enumerated()), id: \.offset) { index, _ in
                    Circle()
                        .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            
            // Pass type info card
            HStack(spacing: 12) {
                Image(systemName: selectedPassStyle.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPassStyle.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(selectedPassStyle.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.2), value: selectedPassStyle)
            
            // Pass status
            HStack(spacing: 8) {
                Image(systemName: card.hasValidPass ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(card.hasValidPass ? .green : .orange)
                Text(card.hasValidPass ? "Pass ready for Wallet" : "Changes require pass regeneration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            // Set initial index based on current style
            if let index = PassStyle.allCases.firstIndex(of: selectedPassStyle) {
                currentIndex = index
            }
        }
    }
    
    @ViewBuilder
    private func passPreview(for style: PassStyle, passWidth: CGFloat, passHeight: CGFloat) -> some View {
        Group {
            switch style {
            case .generic:
                GenericPassPreview(
                    passWidth: passWidth,
                    passHeight: passHeight,
                    displayCompany: displayCompany,
                    displayCardName: displayCardName,
                    displayMember: displayMember,
                    currentBarcodeString: currentBarcodeString,
                    headerField: headerField,
                    expirationDate: expirationDate,
                    auxiliaryField1: auxiliaryField1,
                    auxiliaryField2: auxiliaryField2,
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    selectedIconName: selectedIconName,
                    selectedIconColor: selectedIconColor,
                    barcodeFormat: barcodeFormat
                )
            case .storeCard:
                StoreCardPassPreview(
                    passWidth: passWidth,
                    passHeight: passHeight,
                    displayCompany: displayCompany,
                    displayCardName: displayCardName,
                    displayMember: displayMember,
                    currentBarcodeString: currentBarcodeString,
                    headerField: headerField,
                    expirationDate: expirationDate,
                    auxiliaryField1: auxiliaryField1,
                    auxiliaryField2: auxiliaryField2,
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    selectedIconName: selectedIconName,
                    selectedIconColor: selectedIconColor,
                    barcodeFormat: barcodeFormat
                )
            case .coupon:
                CouponPassPreview(
                    passWidth: passWidth,
                    passHeight: passHeight,
                    displayCompany: displayCompany,
                    displayCardName: displayCardName,
                    displayMember: displayMember,
                    currentBarcodeString: currentBarcodeString,
                    headerField: headerField,
                    expirationDate: expirationDate,
                    auxiliaryField1: auxiliaryField1,
                    auxiliaryField2: auxiliaryField2,
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    selectedIconName: selectedIconName,
                    selectedIconColor: selectedIconColor,
                    barcodeFormat: barcodeFormat
                )
            case .eventTicket:
                EventTicketPassPreview(
                    passWidth: passWidth,
                    passHeight: passHeight,
                    displayCompany: displayCompany,
                    displayCardName: displayCardName,
                    displayMember: displayMember,
                    currentBarcodeString: currentBarcodeString,
                    headerField: headerField,
                    expirationDate: expirationDate,
                    auxiliaryField1: auxiliaryField1,
                    auxiliaryField2: auxiliaryField2,
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    selectedIconName: selectedIconName,
                    selectedIconColor: selectedIconColor,
                    barcodeFormat: barcodeFormat
                )
            }
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Using SF Symbol: \(selectedIconName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Icon color auto-syncs with text color (can override in picker)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Generic Pass Preview
struct GenericPassPreview: View {
    let passWidth: CGFloat
    let passHeight: CGFloat
    let displayCompany: String
    let displayCardName: String
    let displayMember: String
    let currentBarcodeString: String
    let headerField: String
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let card: Card
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    let barcodeFormat: String

    private var fontScale: CGFloat { min(passWidth / 375.0, 1.0) }

    var body: some View {
        VStack(spacing: 0) {
            // Header row: logo left, header field right (matches Apple Wallet layout)
            PassHeaderRow(
                displayCompany: displayCompany,
                displayCardName: displayCardName,
                headerField: headerField,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                selectedIconName: selectedIconName,
                selectedIconColor: selectedIconColor,
                fontScale: fontScale*1.5
            )


            Rectangle()
                .fill(secondaryColor.opacity(0.12))
                .frame(height: 0.5)

            // Body: primary → secondary → auxiliary → barcode
            PassBodyFieldsView(
                displayMember: displayMember,
                primaryLabel: "MEMBER",
                expirationDate: expirationDate,
                auxiliaryField1: auxiliaryField1,
                auxiliaryField2: auxiliaryField2,
                currentBarcodeString: currentBarcodeString,
                secondaryColor: secondaryColor,
                barcodeFormat: barcodeFormat,
                primaryColor: primaryColor,
                compact: false,
                fontScale: fontScale*1.5
            )
        }
        .frame(width: passWidth, height: passHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Store Card Pass Preview
struct StoreCardPassPreview: View {
    let passWidth: CGFloat
    let passHeight: CGFloat
    let displayCompany: String
    let displayCardName: String
    let displayMember: String
    let currentBarcodeString: String
    let headerField: String
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let card: Card
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    let barcodeFormat: String

    private var hasStripImage: Bool {
        selectedBackgroundImage != nil || (!isBannerImageRemoved && card.bannerImage != nil)
    }

    private var fontScale: CGFloat { min(passWidth / 375.0, 1.0) }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            PassHeaderRow(
                displayCompany: displayCompany,
                displayCardName: displayCardName,
                headerField: headerField,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                selectedIconName: selectedIconName,
                selectedIconColor: selectedIconColor,
                fontScale: fontScale*1.5
            )

            // Strip image with primary field overlaid on top.
            // Apple spec: "The strip image is displayed behind the primary fields."
            // StoreCard strip = 375×144pt → ~35% of pass height. Primary fields sit at the TOP of the strip.
            ZStack(alignment: .topLeading) {
                StripImageView(
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    height: passHeight * 0.35
                )
                .frame(width: passWidth) // קיבוע רוחב התמונה

                if !displayMember.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayMember)
                            .font(.system(size: fontScale * 50, weight: .light)) // החזרתי לגודל המקורי
                            .foregroundColor(hasStripImage ? Color.white : secondaryColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .truncationMode(.tail)
                            .allowsTightening(true)
                            .shadow(color: hasStripImage ? Color.black.opacity(0.4) : Color.clear, radius: 1)
                            .frame(width: passWidth - 32, alignment: .leading) 
                        
                        Text("MEMBER")
                            .font(.system(size: fontScale * 15, weight: .medium))
                            .foregroundColor(hasStripImage ? Color.white.opacity(0.85) : secondaryColor.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .frame(width: passWidth, height: passHeight * 0.35, alignment: .topLeading) // קיבוע ה-ZStack

            // Secondary + auxiliary + barcode below the strip (primary is on the strip above)
            PassBodyFieldsView(
                displayMember: displayMember,
                primaryLabel: "MEMBER",
                expirationDate: expirationDate,
                auxiliaryField1: auxiliaryField1,
                auxiliaryField2: auxiliaryField2,
                currentBarcodeString: currentBarcodeString,
                secondaryColor: secondaryColor,
                barcodeFormat: barcodeFormat,
                primaryColor: primaryColor,
                compact: true,
                showPrimaryField: false,
                fontScale: fontScale*1.5
            )
        }
        .frame(width: passWidth, height: passHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Coupon Pass Preview
struct CouponPassPreview: View {
    let passWidth: CGFloat
    let passHeight: CGFloat
    let displayCompany: String
    let displayCardName: String
    let displayMember: String
    let currentBarcodeString: String
    let headerField: String
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let card: Card
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    let barcodeFormat: String

    private var hasStripImage: Bool {
        selectedBackgroundImage != nil || (!isBannerImageRemoved && card.bannerImage != nil)
    }

    private var fontScale: CGFloat { min(passWidth / 375.0, 1.0) }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            PassHeaderRow(
                displayCompany: displayCompany,
                displayCardName: displayCardName,
                headerField: headerField,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                selectedIconName: selectedIconName,
                selectedIconColor: selectedIconColor,
                fontScale: fontScale*1.5
            )

            // Strip image with primary field overlaid on top (same spec as storeCard: 375×144pt)
            ZStack(alignment: .topLeading) {
                StripImageView(
                    selectedBackgroundImage: selectedBackgroundImage,
                    isBannerImageRemoved: isBannerImageRemoved,
                    card: card,
                    primaryColor: primaryColor,
                    height: passHeight * 0.32
                )

                // Primary field on strip — 9pt label, 22pt light value (Apple PassKit spec)
                if !displayMember.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayMember)
                            .font(.system(size: fontScale * 50, weight: .light))
                            .foregroundColor(hasStripImage ? Color.white : secondaryColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .truncationMode(.tail)
                            .shadow(color: hasStripImage ? Color.black.opacity(0.4) : Color.clear, radius: 1)
                        Text("MEMBER")
                            .font(.system(size: fontScale * 15, weight: .medium))
                            .foregroundColor(hasStripImage ? Color.white.opacity(0.85) : secondaryColor.opacity(0.7))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            // Perforated tear edge — separates strip from body on coupons
            HStack(spacing: 3) {

            }
            .frame(height: 6)
            .frame(maxWidth: .infinity)
            .background(primaryColor)

            // Secondary + auxiliary + barcode (primary is overlaid on strip above)
            PassBodyFieldsView(
                displayMember: displayMember,
                primaryLabel: "MEMBER",
                expirationDate: expirationDate,
                auxiliaryField1: auxiliaryField1,
                auxiliaryField2: auxiliaryField2,
                currentBarcodeString: currentBarcodeString,
                secondaryColor: secondaryColor,
                barcodeFormat: barcodeFormat,
                primaryColor: primaryColor,
                compact: true,
                showPrimaryField: false,
                fontScale: fontScale*2
            )
        }
        .frame(width: passWidth, height: passHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Event Ticket Pass Preview
struct EventTicketPassPreview: View {
    let passWidth: CGFloat
    let passHeight: CGFloat
    let displayCompany: String
    let displayCardName: String
    let displayMember: String
    let currentBarcodeString: String
    let headerField: String
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let card: Card
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    let barcodeFormat: String

    private var fontScale: CGFloat { min(passWidth / 375.0, 1.0) }

    var body: some View {
        ZStack {
            // Background image — blurred to match Apple Wallet's eventTicket rendering
            Group {
                if let backgroundImage = selectedBackgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 6)
                } else if !isBannerImageRemoved, let backgroundImage = card.bannerImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 6)
                } else {
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: passWidth, height: passHeight)
            .clipped()

            // Fields in standard PassKit layout: header → primary → secondary/aux → barcode
            // (No gradient overlays — Apple Wallet does not render these)
            VStack(alignment: .leading, spacing: 0) {
                // Header row — logo left, org name, header field right
                HStack(alignment: .center, spacing: 8) {
                    // Logo icon — 26pt symbol, 44×44 frame (Apple PassKit spec)
                    Image(systemName: selectedIconName)
                        .font(.system(size: fontScale * 40, weight: .regular))
                        .foregroundColor(secondaryColor)
                        .frame(width: 44, height: 44)

                    Text(displayCompany)
                        .font(.system(size: fontScale * 20, weight: .semibold))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if !headerField.isEmpty {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(headerField)
                                .font(.system(size: fontScale * 13, weight: .semibold))
                                .foregroundColor(secondaryColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("INFO")
                                .font(.system(size: fontScale * 9, weight: .medium))
                                .foregroundColor(secondaryColor.opacity(0.7))
                                .tracking(0.5)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Primary field — 9pt label, 22pt light value (Apple PassKit spec for eventTicket)
                if !displayMember.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TICKET")
                            .font(.system(size: fontScale * 9, weight: .medium))
                            .foregroundColor(secondaryColor.opacity(0.7))
                            .tracking(0.5)
                        Text(displayMember)
                            .font(.system(size: fontScale * 22, weight: .light))
                            .foregroundColor(secondaryColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Secondary + auxiliary fields — 9pt label, 15pt regular value (Apple PassKit spec)
                if !expirationDate.isEmpty || !auxiliaryField1.isEmpty || !auxiliaryField2.isEmpty {
                    HStack(alignment: .top) {
                        if !expirationDate.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DATE")
                                    .font(.system(size: fontScale * 9, weight: .medium))
                                    .foregroundColor(secondaryColor.opacity(0.7))
                                    .tracking(0.5)
                                Text(expirationDate)
                                    .font(.system(size: fontScale * 15, weight: .regular))
                                    .foregroundColor(secondaryColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        if !auxiliaryField1.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("INFO")
                                    .font(.system(size: fontScale * 9, weight: .medium))
                                    .foregroundColor(secondaryColor.opacity(0.7))
                                    .tracking(0.5)
                                Text(auxiliaryField1)
                                    .font(.system(size: fontScale * 15, weight: .regular))
                                    .foregroundColor(secondaryColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        Spacer()
                        if !auxiliaryField2.isEmpty {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("INFO")
                                    .font(.system(size: fontScale * 9, weight: .medium))
                                    .foregroundColor(secondaryColor.opacity(0.7))
                                    .tracking(0.5)
                                Text(auxiliaryField2)
                                    .font(.system(size: fontScale * 15, weight: .regular))
                                    .foregroundColor(secondaryColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                Spacer()

                // Barcode at bottom
                if !currentBarcodeString.isEmpty {
                    VStack(spacing: 4) {
                        BarcodeImageView(message: currentBarcodeString, format: barcodeFormat)
                            .frame(height: 65)
                            .padding(.horizontal, 20)
                            .padding(.bottom,20)
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: passWidth, height: passHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Shared Pass Components

// MARK: Pass Header Row
/// Reusable header row matching Apple Wallet's exact layout:
/// Logo icon + org name on LEFT, header field (value top / label bottom) on RIGHT.
struct PassHeaderRow: View {
    let displayCompany: String
    var displayCardName: String = ""
    let headerField: String
    let primaryColor: Color
    let secondaryColor: Color
    let selectedIconName: String
    let selectedIconColor: Color
    var fontScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Logo icon — Apple Wallet logo slot (~160×50pt, upper left)
            Image(systemName: selectedIconName)
                .font(.system(size: fontScale * 26, weight: .regular))
                .foregroundColor(selectedIconColor)
                .frame(width: 44, height: 44)

            // Organization name — logoText equivalent, 13pt semibold per PassKit spec
            Text(displayCompany)
                .font(.system(size: fontScale * 13, weight: .semibold))
                .foregroundColor(secondaryColor)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Header field: value on top, label below — Apple Wallet spec
            if !headerField.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(headerField)
                        .font(.system(size: fontScale * 13, weight: .semibold))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("INFO")
                        .font(.system(size: fontScale * 9, weight: .medium))
                        .foregroundColor(secondaryColor.opacity(0.7))
                        .tracking(0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(primaryColor)
    }
}

// MARK: Strip Image View
struct StripImageView: View {
    let selectedBackgroundImage: UIImage?
    let isBannerImageRemoved: Bool
    let card: Card
    let primaryColor: Color
    let height: CGFloat

    var body: some View {
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
                // Slightly darker tint so strip area is visible even without an image
                Rectangle()
                    .fill(primaryColor.opacity(0.85))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.3))
                    )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: Pass Body Fields View
/// Pass body fields: primary (large) → secondary row → auxiliary row → barcode.
/// Matches Apple Wallet's front-of-pass field layout.
struct PassBodyFieldsView: View {
    let displayMember: String
    var primaryLabel: String = "MEMBER"
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let currentBarcodeString: String
    let secondaryColor: Color
    let barcodeFormat: String
    let primaryColor: Color
    var compact: Bool = false
    var showPrimaryField: Bool = true
    var fontScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Primary field — label 9pt ALL CAPS, value 26pt light (Apple PassKit spec)
            if showPrimaryField && !displayMember.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryLabel)
                        .font(.system(size: fontScale * 9, weight: .medium))
                        .foregroundColor(secondaryColor.opacity(0.7))
                        .tracking(0.5)
                    Text(displayMember)
                        .font(.system(size: fontScale * (compact ? 22 : 26), weight: .light))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 16)
                .padding(.top, compact ? 10 : 12)
                .padding(.bottom, 6)
            }

            // Secondary field row — label 9pt, value 15pt regular (Apple PassKit spec)
            if !expirationDate.isEmpty {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: fontScale * 9, weight: .medium))
                            .foregroundColor(secondaryColor.opacity(0.7))
                            .tracking(0.5)
                        Text(expirationDate)
                            .font(.system(size: fontScale * (compact ? 13 : 15), weight: .regular))
                            .foregroundColor(secondaryColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            // Auxiliary fields row — label 9pt, value 15pt regular (Apple PassKit spec)
            if !auxiliaryField1.isEmpty || !auxiliaryField2.isEmpty {
                HStack(alignment: .top) {
                    if !auxiliaryField1.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("INFO")
                                .font(.system(size: fontScale * 9, weight: .medium))
                                .foregroundColor(secondaryColor.opacity(0.7))
                                .tracking(0.5)
                            Text(auxiliaryField1)
                                .font(.system(size: fontScale * (compact ? 13 : 15), weight: .regular))
                                .foregroundColor(secondaryColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    Spacer()
                    if !auxiliaryField2.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("INFO")
                                .font(.system(size: fontScale * 9, weight: .medium))
                                .foregroundColor(secondaryColor.opacity(0.7))
                                .tracking(0.5)
                            Text(auxiliaryField2)
                                .font(.system(size: fontScale * (compact ? 13 : 15), weight: .regular))
                                .foregroundColor(secondaryColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            Spacer()

            // Barcode — bottom center, matching Apple Wallet
            if !currentBarcodeString.isEmpty {
                VStack(spacing: 4) {
                    BarcodeImageView(message: currentBarcodeString, format: barcodeFormat)
                        .frame(height: compact ? 60 : 70)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(primaryColor)
    }
}

// Keep PassFieldsView as a thin wrapper so any future callsites still compile.
struct PassFieldsView: View {
    let headerField: String
    let displayMember: String
    let expirationDate: String
    let auxiliaryField1: String
    let auxiliaryField2: String
    let currentBarcodeString: String
    let secondaryColor: Color
    let barcodeFormat: String
    let primaryColor: Color
    var compact: Bool = false
    var topPadding: CGFloat = 16

    var body: some View {
        PassBodyFieldsView(
            displayMember: displayMember,
            expirationDate: expirationDate,
            auxiliaryField1: auxiliaryField1,
            auxiliaryField2: auxiliaryField2,
            currentBarcodeString: currentBarcodeString,
            secondaryColor: secondaryColor,
            barcodeFormat: barcodeFormat,
            primaryColor: primaryColor,
            compact: compact
        )
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
    let passStyle: PassStyle
    let onSelectImage: () -> Void
    let onRemoveImage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pass Customization")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(passStyle.supportsImage ? "Customize the \(passStyle.supportsBackgroundImage ? "background" : "strip") image and colors" : "Customize colors (Generic passes use logo only)")
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
            
            // Only show image picker for types that support images
            if passStyle.supportsImage {
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
                        Text("\(passStyle.imageTypeName) Image")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Image dimensions badge
                        Text(passStyle.imageDimensions)
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
                                    .frame(height: passStyle.supportsBackgroundImage ? 160 : 100)
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
                                    .frame(height: passStyle.supportsBackgroundImage ? 160 : 100)
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: passStyle.supportsBackgroundImage ? "photo.fill" : "photo.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundColor(.blue)
                                            Text("Tap to add \(passStyle.imageTypeName) image")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                            Text("Required: \(passStyle.imageDimensions) pixels")
                                                .font(.caption2)
                                                .foregroundColor(.secondary.opacity(0.7))
                                        }
                                        .padding(.horizontal)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: onSelectImage) {
                            HStack {
                                Image(systemName: "photo").foregroundColor(.blue)
                                Text(displayImage == nil ? "Add \(passStyle.imageTypeName)" : "Change \(passStyle.imageTypeName)")
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
            }
            
            Text(passStyle.visualNote)
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
    @Binding var barcodeFormat: String
    let passStyle: PassStyle
    
    var body: some View {
        let limits = passStyle.fieldLimits
        
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
                    // Header fields - only show if supported
                    if limits.header > 0 {
                        EditField(
                            title: "Header Field",
                            text: $headerField,
                            placeholder: limits.header == 1 ? "Single header field" : "Optional header text"
                        )
                    }
                    
                    // Primary fields - only show if supported
                    if limits.primary > 0 {
                        EditField(
                            title: "Membership Number",
                            text: $membershipNumber,
                            placeholder: limits.primary == 1 ? "Primary field (required)" : "Member ID or account number"
                        )
                    }
                    
                    // Secondary fields (expiration) - show for all pass types
                    EditField(title: "Expiration Date", text: $expirationDate, placeholder: "MM/YY (optional)")
                    
                    // Auxiliary fields - only show based on limit
                    if limits.auxiliary > 0 {
                        EditField(
                            title: "Auxiliary Info 1",
                            text: $auxiliaryField1,
                            placeholder: "Additional info (optional)"
                        )
                    }
                    
                    if limits.auxiliary > 1 {
                        EditField(
                            title: "Auxiliary Info 2",
                            text: $auxiliaryField2,
                            placeholder: "Additional info (optional)"
                        )
                    }
                    
                    if limits.auxiliary > 2 {
                        // Future: Add more auxiliary fields if needed
                        // For now, we only track 2 auxiliary fields in the view state
                    }
                }
                
                FieldGroup(title: "Barcode / QR Code") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Format")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Picker("Barcode Format", selection: $barcodeFormat) {
                            Text("QR Code").tag("PKBarcodeFormatQR")
                            Text("Standard Barcode").tag("PKBarcodeFormatCode128")
                        }
                        .pickerStyle(.segmented)
                    }
                    EditField(title: "Barcode Data", text: $barcodeString, placeholder: "Barcode or QR code data")
                    if !barcodeString.isEmpty {
                        BarcodeImageView(message: barcodeString, format: barcodeFormat)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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

// MARK: - Barcode Image View

/// Renders a real barcode or QR code image from a message string using Core Image filters.
/// Supports all four PassKit barcode formats: QR, Code128, PDF417, Aztec.
struct BarcodeImageView: View {
    let message: String
    let format: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(.white)
            if let barcodeImage = generateBarcode() {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
    }

    private func generateBarcode() -> UIImage? {
        guard !message.isEmpty else { return nil }

        // PassKit requires iso-8859-1 encoding for barcode message data
        guard let data = message.data(using: .isoLatin1) ?? message.data(using: .utf8) else { return nil }

        let filterName: String
        let isSquare: Bool

        switch format {
        case "PKBarcodeFormatQR":
            filterName = "CIQRCodeGenerator"
            isSquare = true
        case "PKBarcodeFormatPDF417":
            filterName = "CIPDF417BarcodeGenerator"
            isSquare = false
        case "PKBarcodeFormatAztec":
            filterName = "CIAztecCodeGenerator"
            isSquare = true
        default: // PKBarcodeFormatCode128
            filterName = "CICode128BarcodeGenerator"
            isSquare = false
        }

        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(data, forKey: "inputMessage")

        if filterName == "CIQRCodeGenerator" {
            // Medium error correction — good balance of size vs. scanability
            filter.setValue("M", forKey: "inputCorrectionLevel")
        }

        guard let outputImage = filter.outputImage else { return nil }

        // Scale to a crisp pixel size (2× for retina sharpness)
        let targetSize: CGSize = isSquare
            ? CGSize(width: 200, height: 200)
            : CGSize(width: 400, height: 100)
        let scaleX = targetSize.width / outputImage.extent.width
        let scaleY = targetSize.height / outputImage.extent.height
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Card.self, configurations: config)
    
    let studentCard = Card(
        organizationName: "המכללה האקדמית להנדסה ע\"ש סמי שמעון",
        passDescription: "כרטיס סטודנט",
        foregroundColor: "#FFFFFF",
        backgroundColor: "#105973",
        barcodeMessage: "324268648",
        barcodeFormat: "PKBarcodeFormatCode128",
        passStyle: PassStyle.generic.rawValue,
        isDraft: false
    )
    
    studentCard.updatePrimaryFields([
        PassField(key: "studentName", label: "שם בעל הכרטיס", value: "Farangi Yuval")
    ])
    
    studentCard.updateSecondaryFields([
        PassField(key: "idNumber", label: "תעודת זהות", value: "324268648"),
        PassField(key: "hebrewName", label: "שם מלא (עברית)", value: "פאראנגי יובל חי")
    ])
    
    studentCard.updateAuxiliaryFields([
        PassField(key: "academicYear", label: "תשפו", value: "2025-2026"),
        PassField(key: "academicInstitution", label: "שם המוסד האקדמי", value: "סמי שמעון")
    ])
    
    container.mainContext.insert(studentCard)
    
    return EditCardView(card: studentCard, onSave: nil)
        .modelContainer(container)
}
