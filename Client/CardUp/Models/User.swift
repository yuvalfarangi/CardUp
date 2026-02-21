//
//  User.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import SwiftData

@Model
final class User {
    var appleUserId: String
    var firstName: String?
    var lastName: String?
    var email: String?
    var subscriptionType: SubscriptionType
    var creationDate: Date
    
    init(
        appleUserId: String,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        subscriptionType: SubscriptionType = .free,
        creationDate: Date = Date()
    ) {
        self.appleUserId = appleUserId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.subscriptionType = subscriptionType
        self.creationDate = creationDate
    }
}

// MARK: - Computed Properties
extension User {
    var fullName: String? {
        guard let firstName = firstName else { return nil }
        let lastName = lastName ?? ""
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var displayName: String {
        return fullName ?? email ?? "User"
    }
    
    var isProUser: Bool {
        return subscriptionType == .pro
    }
}

// MARK: - Supporting Types

enum SubscriptionType: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
    
    var description: String {
        switch self {
        case .free:
            return "Limited to 3 cards"
        case .pro:
            return "Unlimited cards and features"
        }
    }
}