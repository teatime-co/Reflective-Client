//
//  ReflectiveApp.swift
//  Reflective
//
//  Created by Raffy Castillo on 7/21/25.
//

import SwiftUI

@main
struct ReflectiveApp: App {
    let container = NSPersistentContainer(name: "Reflective")
    let windowController: WindowStateController
    let dataController: DataController

    init() {
        // Enable Core Data debug options
        #if DEBUG
        UserDefaults.standard.setValue(true, forKey: "_NSCoreDataDebugOptionsKey")
        #endif
        
        // init container
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Failed to load Core Data stack: \(error)")
            }
            // Enable persistent history tracking
            description.setOption(true as NSNumber, 
                                forKey: NSPersistentHistoryTrackingKey)
        }

        // Create controllers in correct order
        dataController = DataController(container: container)
        windowController = WindowStateController(container: container, dataController: dataController)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(windowController)
                .environmentObject(dataController)
        }
    }
}
