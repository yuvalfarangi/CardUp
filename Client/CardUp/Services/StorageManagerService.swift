//
//  StorageManagerService.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import SwiftData
import CloudKit
import CoreData

@Observable
final class StorageManagerService {
    var modelContext: ModelContext?
    var syncError: String?
    var isSyncing: Bool = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupCloudKitSync()
    }
    
    // MARK: - Card Management
    
    func saveCard(_ card: Card) throws {
        guard let context = modelContext else {
            throw StorageError.noContext
        }
        
        context.insert(card)
        try context.save()
    }
    
    func deleteCard(_ card: Card) throws {
        guard let context = modelContext else {
            throw StorageError.noContext
        }
        
        context.delete(card)
        try context.save()
    }
    
    func fetchCards(isDraft: Bool? = nil) -> [Card] {
        guard let context = modelContext else { return [] }
        
        var predicate: Predicate<Card>
        if let isDraftValue = isDraft {
            predicate = #Predicate<Card> { card in
                card.isDraft == isDraftValue
            }
        } else {
            predicate = #Predicate<Card> { _ in true }
        }
        
        let descriptor = FetchDescriptor<Card>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch cards: \(error)")
            return []
        }
    }
    
    func fetchDraftCards() -> [Card] {
        return fetchCards(isDraft: true)
    }
    
    func fetchWalletCards() -> [Card] {
        return fetchCards(isDraft: false)
    }
    
    func markCardAsAddedToWallet(_ card: Card) throws {
        card.isAddedToWallet = true
        card.isDraft = false
        try saveCard(card)
    }
    
    func updateCard(_ card: Card, with data: ExtractedCardData) throws {
        let jsonData = try JSONEncoder().encode(data)
        card.extractedTextJson = String(data: jsonData, encoding: .utf8) ?? ""
        try saveCard(card)
    }
    
    // MARK: - User Management
    
    func saveUser(_ user: User) throws {
        guard let context = modelContext else {
            throw StorageError.noContext
        }
        
        // Check if user already exists
        let descriptor = FetchDescriptor<User>()
        let allUsers = try context.fetch(descriptor)
        let existingUsers = allUsers.filter { $0.appleUserId == user.appleUserId }
        
        if existingUsers.isEmpty {
            context.insert(user)
        } else if let existingUser = existingUsers.first {
            // Update existing user with new information
            if user.firstName != nil { existingUser.firstName = user.firstName }
            if user.lastName != nil { existingUser.lastName = user.lastName }
            if user.email != nil { existingUser.email = user.email }
            existingUser.subscriptionType = user.subscriptionType
        }
        
        try context.save()
    }
    
    func fetchUser(appleUserId: String) -> User? {
        guard let context = modelContext else { return nil }
        
        do {
            let descriptor = FetchDescriptor<User>()
            let allUsers = try context.fetch(descriptor)
            return allUsers.first { $0.appleUserId == appleUserId }
        } catch {
            print("Failed to fetch user: \(error)")
            return nil
        }
    }
    
    // MARK: - CloudKit Sync
    
    private func setupCloudKitSync() {
        // Monitor for CloudKit sync errors
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudKitNotification(notification)
        }
    }
    
    private func handleCloudKitNotification(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }
        
        if let error = event.error {
            self.syncError = "iCloud sync error: \(error.localizedDescription)"
        } else if event.type == .export {
            self.isSyncing = event.endDate == nil
        }
    }
    
    func forceSyncWithCloudKit() async {
        isSyncing = true
        syncError = nil
        
        // Trigger a manual sync - implementation depends on your SwiftData/CloudKit setup
        // This is a placeholder for the actual sync mechanism
        
        try? await Task.sleep(for: .seconds(2))
        
        isSyncing = false
    }
}

// MARK: - Error Types

enum StorageError: LocalizedError {
    case noContext
    case saveFailed
    case deleteFailed
    case fetchFailed
    case cloudKitSyncFailed
    
    var errorDescription: String? {
        switch self {
        case .noContext:
            return "No model context available"
        case .saveFailed:
            return "Failed to save data"
        case .deleteFailed:
            return "Failed to delete data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .cloudKitSyncFailed:
            return "CloudKit sync failed"
        }
    }
}