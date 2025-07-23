//
//  ReflectiveApp.swift
//  Reflective
//
//  Created by Raffy Castillo on 7/21/25.
//

import SwiftUI
import CoreData

@main
struct ReflectiveApp: App {
    let container: NSPersistentContainer
    let windowController: WindowStateController
    let dataController: DataController

    init() {
        // Enable Core Data debug options
        #if DEBUG
        UserDefaults.standard.setValue(true, forKey: "_NSCoreDataDebugOptionsKey")
        #endif
        
        // Setup container with migration options
        container = NSPersistentContainer(name: "Reflective")
        
        // Configure migration options
        let description = NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Set a specific URL in Application Support directory (sandbox-friendly)
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Reflective")
        
        // Create directory if it doesn't exist
        if let storeURL = storeURL {
            do {
                try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
                let dbURL = storeURL.appendingPathComponent("Reflective.sqlite")
                description.url = dbURL
                print("Setting persistent store URL to: \(dbURL.path)")
            } catch {
                print("Error creating directory: \(error)")
            }
        }
        
        container.persistentStoreDescriptions = [description]
        
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Failed to load Core Data stack: \(error)")
            }
            // Enable persistent history tracking
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentHistoryTrackingKey)
            
            print("Successfully loaded persistent store: \(description.url?.absoluteString ?? "unknown")")
        }

        // Create controllers in correct order
        dataController = DataController(container: container)
        windowController = WindowStateController(container: container)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(windowController)
                .environmentObject(dataController)
                .environment(\.managedObjectContext, container.viewContext)
        }
    }
}
