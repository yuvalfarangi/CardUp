//
//  CardUpApp.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import SwiftData

@main
struct CardUpApp: App {
    private static func createModelContainer() -> ModelContainer {
        let schema = Schema([
            User.self,
            Card.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ ModelContainer creation failed: \(error)")
            
            // For development: If schema changed, try in-memory fallback
            #if DEBUG
            print("🔄 Using in-memory storage for development...")
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("❌ Could not create ModelContainer: \(error)")
            }
            #else
            fatalError("❌ Could not create ModelContainer: \(error)")
            #endif
        }
    }
    
    var sharedModelContainer: ModelContainer = CardUpApp.createModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
