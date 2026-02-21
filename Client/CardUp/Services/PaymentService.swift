//
//  PaymentService.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import StoreKit
import SwiftUI

@Observable
final class PaymentService {
    var hasProAccess: Bool = false
    var subscriptions: [Product] = []
    var isLoading: Bool = false
    var error: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // Product identifiers - these should match your App Store Connect configuration
    private let proMonthlyId = "com.yourcompany.cardUp.pro.monthly"
    private let proYearlyId = "com.yourcompany.cardUp.pro.yearly"
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        isLoading = true
        error = nil
        
        do {
            let productIds = [proMonthlyId, proYearlyId]
            let storeProducts = try await Product.products(for: productIds)
            
            await MainActor.run {
                subscriptions = storeProducts.sorted { product1, product2 in
                    // Sort by price (monthly first, then yearly)
                    product1.price < product2.price
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load products: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Purchase Management
    
    func purchase(product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            await handleVerificationResult(verificationResult)
        case .userCancelled:
            throw PaymentError.userCancelled
        case .pending:
            // Handle pending transaction (e.g., parental controls)
            await MainActor.run {
                error = "Purchase is pending approval"
            }
        @unknown default:
            throw PaymentError.unknown
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        error = nil
        
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Check if transaction is for our pro subscription
                if transaction.productID == proMonthlyId || transaction.productID == proYearlyId {
                    hasActiveSubscription = true
                    break
                }
            }
        }
        
        await MainActor.run {
            hasProAccess = hasActiveSubscription
        }
    }
    
    // MARK: - Transaction Listening
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleVerificationResult(result)
            }
        }
    }
    
    private func handleVerificationResult(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Update subscription status when we get a verified transaction
            await updateSubscriptionStatus()
            await transaction.finish()
        case .unverified:
            // Handle unverified transaction
            await MainActor.run {
                error = "Transaction could not be verified"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func getDisplayPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func getSubscriptionPeriod(for product: Product) -> String {
        guard let subscription = product.subscription else { return "" }
        
        let period = subscription.subscriptionPeriod
        switch period.unit {
        case .month:
            return period.value == 1 ? "per month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "per year" : "\(period.value) years"
        case .week:
            return period.value == 1 ? "per week" : "\(period.value) weeks"
        case .day:
            return period.value == 1 ? "per day" : "\(period.value) days"
        @unknown default:
            return ""
        }
    }
    
    var monthlyProduct: Product? {
        return subscriptions.first { $0.id == proMonthlyId }
    }
    
    var yearlyProduct: Product? {
        return subscriptions.first { $0.id == proYearlyId }
    }
}

// MARK: - Error Types

enum PaymentError: LocalizedError {
    case userCancelled
    case productNotFound
    case transactionFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .productNotFound:
            return "Product not found"
        case .transactionFailed:
            return "Transaction failed"
        case .unknown:
            return "Unknown payment error"
        }
    }
}