//
//  AuthenticationService.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import Foundation
import AuthenticationServices
import Security
import SwiftData

@Observable
final class AuthenticationService {
    // MARK: - 🚧 DEVELOPMENT MODE - BYPASS LOGIN 🚧
    // Set this to false to re-enable authentication
    private let bypassLogin = true
    
    var isAuthenticated: Bool = false
    var currentUser: User?
    var isLoading: Bool = false
    var error: String?
    
    private let keychain = KeychainHelper()
    private let userIdKey = "appleUserId"
    
    init() {
        // Skip authentication in development mode
        if bypassLogin {
            isAuthenticated = true
            isLoading = false
            // Create a mock user for development
            currentUser = User(
                appleUserId: "dev-user-id",
                firstName: "Developer",
                lastName: "User",
                email: "dev@example.com"
            )
        } else {
            Task {
                await verifySession()
            }
        }
    }
    
    // Allow setting model context for persistence
    weak var modelContext: ModelContext?
    
    // MARK: - Authentication Methods
    
    func handleAuthorization(result: Result<ASAuthorization, Error>) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let authorization = try result.get()
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthenticationError.invalidCredential
            }
            
            let userId = appleIDCredential.user
            
            // Validate that we received a valid user ID
            guard !userId.isEmpty else {
                throw AuthenticationError.invalidCredential
            }
            
            // Save to keychain
            keychain.set(userId, forKey: userIdKey)
            
            // Create or update user
            await MainActor.run {
                let user = User(
                    appleUserId: userId,
                    firstName: appleIDCredential.fullName?.givenName,
                    lastName: appleIDCredential.fullName?.familyName,
                    email: appleIDCredential.email
                )
                
                // Persist to SwiftData if context is available
                if let modelContext = modelContext {
                    // Check if user already exists
                    let descriptor = FetchDescriptor<User>(
                        predicate: #Predicate { $0.appleUserId == userId }
                    )
                    
                    if let existingUser = try? modelContext.fetch(descriptor).first {
                        // Update existing user with new information (if available)
                        if let firstName = appleIDCredential.fullName?.givenName {
                            existingUser.firstName = firstName
                        }
                        if let lastName = appleIDCredential.fullName?.familyName {
                            existingUser.lastName = lastName
                        }
                        if let email = appleIDCredential.email {
                            existingUser.email = email
                        }
                        currentUser = existingUser
                    } else {
                        // Insert new user
                        modelContext.insert(user)
                        currentUser = user
                    }
                    
                    try? modelContext.save()
                } else {
                    currentUser = user
                }
                
                isAuthenticated = true
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                // Debug information
                print("=== Authentication Error Details ===")
                print("Error: \(error)")
                print("Error type: \(type(of: error))")
                print("Error domain: \((error as NSError).domain)")
                print("Error code: \((error as NSError).code)")
                print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
                print("Running on Simulator: \(isSimulator)")
                
                if let authError = error as? ASAuthorizationError {
                    print("ASAuthorizationError code: \(authError.code.rawValue)")
                    print("ASAuthorizationError description: \(authError.localizedDescription)")
                    print("Underlying error: \(String(describing: authError.errorUserInfo))")
                    
                    #if targetEnvironment(simulator)
                    if authError.code.rawValue == 1000 {
                        print("⚠️ Error 1000 on Simulator - Check if you're signed into Apple ID in Settings")
                    }
                    #endif
                }
                
                // Provide more specific error messages
                if let authError = error as? ASAuthorizationError {
                    switch authError.code {
                    case .canceled:
                        self.error = "Sign in was canceled"
                    case .failed:
                        #if targetEnvironment(simulator)
                        self.error = "Sign in failed on Simulator. Make sure you're signed into Apple ID in Settings app."
                        #else
                        self.error = "Sign in failed. This usually means Sign in with Apple is not properly configured in your Apple Developer account. Error code: \((error as NSError).code)"
                        #endif
                    case .invalidResponse:
                        self.error = "Invalid response from Apple. Please try again."
                    case .notHandled:
                        self.error = "Sign in not handled properly. Please contact support."
                    case .unknown:
                        #if targetEnvironment(simulator)
                        self.error = "Unknown error on Simulator. Ensure you're signed into Apple ID in Settings and have 2FA enabled."
                        #else
                        self.error = "Unknown error (code: \((error as NSError).code)). Check that Sign in with Apple capability is enabled in Xcode and your Apple Developer account."
                        #endif
                    @unknown default:
                        self.error = "Authentication error: \(error.localizedDescription) (code: \((error as NSError).code))"
                    }
                } else {
                    self.error = error.localizedDescription
                }
                
                isAuthenticated = false
                isLoading = false
            }
        }
    }
    
    func verifySession() async {
        // Skip verification in development mode
        if bypassLogin {
            await MainActor.run {
                isAuthenticated = true
                isLoading = false
            }
            return
        }
        
        isLoading = true
        
        guard let userId = keychain.get(userIdKey) else {
            await MainActor.run {
                isAuthenticated = false
                isLoading = false
            }
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        
        do {
            let credentialState = try await provider.credentialState(forUserID: userId)
            
            await MainActor.run {
                switch credentialState {
                case .authorized:
                    // Create user object with stored ID (other info might not be available)
                    currentUser = User(appleUserId: userId)
                    isAuthenticated = true
                case .revoked, .notFound:
                    signOut()
                case .transferred:
                    // Handle transferred account
                    signOut()
                @unknown default:
                    signOut()
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isAuthenticated = false
                isLoading = false
            }
        }
    }
    
    func signOut() {
        keychain.delete(userIdKey)
        currentUser = nil
        isAuthenticated = false
        error = nil
    }
    
    // MARK: - Sign In With Apple Request
    
    func createSignInRequest() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Add debugging information
        print("=== Sign in with Apple Debug Info ===")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("Running on Simulator: \(isSimulator)")
        print("iOS Version: \(UIDevice.current.systemVersion)")
        print("Team ID: \(Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "Unknown")")
        
        // Check entitlements
        if let entitlements = Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.applesignin") {
            print("✅ Sign in with Apple entitlement found: \(entitlements)")
        } else {
            print("❌ ERROR: Sign in with Apple entitlement NOT found!")
            print("   This is why you're getting Error 1000")
            print("   Action required: Add 'Sign in with Apple' capability in Xcode")
        }
        
        #if targetEnvironment(simulator)
        print("⚠️ Running on Simulator - Make sure you're signed into Apple ID in Settings")
        #endif
        
        return request
    }
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Error Types

enum AuthenticationError: LocalizedError {
    case invalidCredential
    case keychainError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .keychainError:
            return "Failed to save authentication data"
        case .networkError:
            return "Network error during authentication"
        }
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    private let service: String
    
    init() {
        // Use the actual bundle identifier
        service = Bundle.main.bundleIdentifier ?? "com.yuvalfarangi.CardUp"
    }
    
    func set(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
