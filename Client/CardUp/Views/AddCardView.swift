//
//  AddCardView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import PhotosUI
import SwiftData
import PassKit

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var cardProcessingService = CardProcessingService()
    @State private var cameraPermissionManager = CameraPermissionManager()
    @State private var passKitIntegrator = PassKitIntegrator()
    
    // State management
    @State private var currentState: AddCardState = .initial
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showEditCard = false
    @State private var createdCard: Card?
    @State private var showAddToWallet = false
    @State private var generatedPassData: Data?
    
    // Animation states
    @State private var processingProgress: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    switch currentState {
                    case .initial:
                        MediaSelectionView(
                            onTakePhoto: handleTakePhoto,
                            onUploadPhoto: { showImagePicker = true }
                        )
                        
                    case .reviewing:
                        if let image = selectedImage {
                            ReviewImageView(
                                image: image,
                                onRetake: handleRetake,
                                onReupload: handleReupload,
                                onConfirm: handleConfirm,
                                onCancel: handleCancel
                            )
                        }
                        
                    case .processing:
                        if let image = selectedImage {
                            ProcessingView(
                                image: image,
                                progress: processingProgress,
                                glowOpacity: glowOpacity,
                                onCancel: handleCancel
                            )
                        }
                        
                    case .generating:
                        if let image = selectedImage {
                            PassGenerationView(
                                image: image,
                                progress: processingProgress,
                                onCancel: handleCancel,
                                onAddToWallet: handleAddToWallet,
                                onEditCard: handleEditCard
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        currentState = .reviewing
                    }
                }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newValue in
            Task {
                await handlePhotoSelection(newValue)
            }
        }
        .onChange(of: cardProcessingService.isProcessing) { oldValue, newValue in
            // When processing finishes (isProcessing becomes false)
            if oldValue == true && newValue == false {
                handleProcessingComplete()
            }
        }
        .onChange(of: cardProcessingService.processingProgress) { _, newProgress in
            processingProgress = newProgress
        }
        .onAppear {
            // Start glow animation on appear
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
        .fullScreenCover(isPresented: $showEditCard) {
            if let card = createdCard {
                EditCardView(card: card) {
                    // On save callback
                    showEditCard = false
                    
                    // Ask user if they want to add to wallet or continue editing
                    if card.pkpassData != nil {
                        generatedPassData = card.pkpassData
                        currentState = .generating
                    }
                }
            }
        }
        .addPassToWallet(
            passData: showAddToWallet ? generatedPassData : nil,
            onSuccess: handleWalletSuccess,
            onError: handleWalletError
        )
    }
    
    // MARK: - Action Handlers
    
    private func handleTakePhoto() {
        Task {
            let hasPermission = await cameraPermissionManager.requestPermission()
            
            await MainActor.run {
                if hasPermission {
                    showCamera = true
                } else {
                    // Handle permission denied - could show alert
                    print("Camera permission denied")
                }
            }
        }
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    currentState = .reviewing
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    private func handleRetake() {
        selectedImage = nil
        currentState = .initial
        showCamera = true
    }
    
    private func handleReupload() {
        selectedImage = nil
        currentState = .initial
        showImagePicker = true
    }
    
    private func handleConfirm() {
        guard let image = selectedImage else { return }
        
        currentState = .processing
        
        // Create a new card immediately
        let newCard = Card()
        modelContext.insert(newCard)
        createdCard = newCard
        
        Task {
            print(image)
            print(newCard)
            await cardProcessingService.generateWalletPass(from: image, for: newCard)
        }
    }
    
    private func handleCancel() {
        dismiss()
    }
    
    private func handleProcessingComplete() {
        guard let card = createdCard else { return }
        
        // Check if we have a generated pass or if it's a draft
        let hasGeneratedPass = cardProcessingService.generatedPassData != nil
        
        if hasGeneratedPass {
            // Server successfully generated a pass - show "Add to Wallet" option
            generatedPassData = cardProcessingService.generatedPassData
            
            // Update card with generated pass data
            card.pkpassData = generatedPassData
            
            // Try to save changes
            do {
                try modelContext.save()
            } catch {
                print("Failed to save card: \(error)")
            }
            
            // Show options to add to wallet or edit
            currentState = .generating
            
            // Start glow animation for success state
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        } else {
            // Server analysis failed - card is marked as draft, go directly to edit view
            print("ℹ️ Server analysis failed or unavailable - opening edit view for manual entry")
            
            // Try to save the draft card
            do {
                try modelContext.save()
            } catch {
                print("Failed to save draft card: \(error)")
            }
            
            // Go directly to edit view for manual entry
            showEditCard = true
        }
    }
    
    private func handleAddToWallet() {
        guard let passData = generatedPassData,
              let card = createdCard else { return }
        
        showAddToWallet = true
    }
    
    private func handleEditCard() {
        guard let card = createdCard else { return }
        showEditCard = true
    }
    
    private func handleWalletSuccess() {
        guard let card = createdCard else { return }
        
        // Mark card as added to wallet
        card.isAddedToWallet = true
        card.isDraft = false
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to update card status: \(error)")
        }
        
        // Dismiss the view
        dismiss()
    }
    
    private func handleWalletError(_ error: Error) {
        print("Failed to add to wallet: \(error.localizedDescription)")
        // Continue gracefully - user can try again or edit the card
    }
}

// MARK: - State Machine

enum AddCardState {
    case initial
    case reviewing
    case processing
    case generating
}

// MARK: - Media Selection View

struct MediaSelectionView: View {
    let onTakePhoto: () -> Void
    let onUploadPhoto: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero Icon
            VStack(spacing: 16) {
                Image(systemName: "creditcard.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(spacing: 8) {
                    Text("Add Your Card")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Take a photo or upload an image of your loyalty card")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                // Take Photo Button
                Button(action: onTakePhoto) {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.headline)
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
                }
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Upload Photo Button
                Button(action: onUploadPhoto) {
                    Label("Upload Photo", systemImage: "photo.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.regularMaterial, in: Capsule())
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Review Image View

struct ReviewImageView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onReupload: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Image Preview
            VStack(spacing: 16) {
                Text("Review Your Card")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // Card Image with Glass Effect Frame
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .frame(height: 240)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(8)
                }
                .padding(.horizontal, 32)
                
                Text("Make sure all text is clear and readable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                // Confirm Button (Primary)
                Button(action: onConfirm) {
                    Text("Confirm")
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
                
                // Secondary Actions
                HStack(spacing: 12) {
                    Button("Retake", action: onRetake)
                        .buttonStyle(SecondaryGlassButtonStyle())
                    
                    Button("Reupload", action: onReupload)
                        .buttonStyle(SecondaryGlassButtonStyle())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Processing View

struct ProcessingView: View {
    let image: UIImage
    let progress: Double
    let glowOpacity: Double
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Processing Animation
            VStack(spacing: 24) {
                Text("Processing Card")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                ZStack {
                    // Base Image with Glass Frame
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .frame(height: 240)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(8)
                    
                    // Progress Indicator
                    VStack {
                        Spacer()
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(1.2)
                            .padding()
                    }
                    
                    // Glowing Border Effect
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .opacity(glowOpacity)
                        .padding(8)
                }
                .padding(.horizontal, 32)
                
                // AI Processing Indicator
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                            .symbolEffect(.variableColor.iterative, options: .repeating)
                        
                        Text("CardUp doing its magic")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text(getProgressDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Cancel Button
            Button("Cancel", action: onCancel)
                .buttonStyle(SecondaryGlassButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
    }
    
    private func getProgressDescription() -> String {
        switch progress {
        case 0.0..<0.2:
            return "Preparing image for analysis..."
        case 0.2..<0.4:
            return "Sending to AI server for analysis..."
        case 0.4..<0.6:
            return "Analyzing card details..."
        case 0.6..<0.8:
            return "Extracting colors and design..."
        case 0.8..<1.0:
            return "Finalizing card details..."
        default:
            return "Complete!"
        }
    }
}

// MARK: - Pass Generation View

struct PassGenerationView: View {
    let image: UIImage
    let progress: Double
    let onCancel: () -> Void
    let onAddToWallet: () -> Void
    let onEditCard: () -> Void
    
    // Check if we're in development mode
    private var isDevelopmentMode: Bool {
        // This should match the flag in PassKitIntegrator
        return true
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("Pass Generated Successfully")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // Pass Preview Animation
                ZStack {
                    // Wallet Pass Preview
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 320, height: 200)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                        .scaleEffect(0.8)
                    
                    VStack {
                        HStack {
                            Image(systemName: "wallet.pass.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Spacer()
                            Text("Apple Wallet")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("Loyalty Card")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Text(isDevelopmentMode ? "Card data saved" : "Ready to add to Wallet")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom)
                    }
                    .frame(width: 320, height: 200)
                    .scaleEffect(0.8)
                }
                
                // Success Message
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        Text(isDevelopmentMode ? "Card Saved Successfully" : "Pass Generated Successfully")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    if isDevelopmentMode {
                        Text("Development Mode: Card data has been saved. You can edit the details or configure CloudFlare Worker to enable Apple Wallet integration.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Your Apple Wallet pass is ready. You can add it to your wallet or edit the details first.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                // Edit Card Button (Primary in dev mode, secondary in production)
                Button(action: onEditCard) {
                    Label("Edit Card Details", systemImage: "pencil")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isDevelopmentMode ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Group {
                                if isDevelopmentMode {
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [.clear, .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .background(.regularMaterial, in: Capsule())
                        .clipShape(Capsule())
                        .glassEffect(isDevelopmentMode ? .regular.tint(.blue).interactive() : .regular.interactive(), in: .capsule)
                }
                .shadow(color: isDevelopmentMode ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                
                // Add to Wallet Button (only in production mode)
                if !isDevelopmentMode {
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
                }
                
                // Done button in dev mode
                if isDevelopmentMode {
                    Button("Done") {
                        onCancel()
                    }
                    .buttonStyle(SecondaryGlassButtonStyle())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Secondary Button Style

struct SecondaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.regularMaterial, in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview Support

#Preview("Initial State") {
    AddCardView()
        .modelContainer(for: Card.self, inMemory: true)
}

#Preview("Review State") {
    AddCardViewPreview(state: .reviewing)
        .modelContainer(for: Card.self, inMemory: true)
}

#Preview("Processing State") {
    AddCardViewPreview(state: .processing)
        .modelContainer(for: Card.self, inMemory: true)
}

#Preview("Generation State") {
    AddCardViewPreview(state: .generating)
        .modelContainer(for: Card.self, inMemory: true)
}

// Helper for previews
private struct AddCardViewPreview: View {
    let state: AddCardState
    
    var body: some View {
        NavigationStack {
            VStack {
                if state == .reviewing {
                    ReviewImageView(
                        image: UIImage(systemName: "creditcard.fill") ?? UIImage(),
                        onRetake: {},
                        onReupload: {},
                        onConfirm: {},
                        onCancel: {}
                    )
                } else if state == .processing {
                    ProcessingView(
                        image: UIImage(systemName: "creditcard.fill") ?? UIImage(),
                        progress: 0.5,
                        glowOpacity: 0.7,
                        onCancel: {}
                    )
                } else if state == .generating {
                    PassGenerationView(
                        image: UIImage(systemName: "creditcard.fill") ?? UIImage(),
                        progress: 1.0,
                        onCancel: {},
                        onAddToWallet: {},
                        onEditCard: {}
                    )
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
