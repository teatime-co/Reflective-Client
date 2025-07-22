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

        // share the same container between controllers
        windowController = WindowStateController(container: container)
        dataController = DataController(container: container)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(windowController)
                .environmentObject(dataController)
        }
    }
}
