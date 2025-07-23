//
//  Persistence.swift
//  Reflective
//
//  Created by Raffy Castillo on 7/21/25.
//

import CoreData
import SwiftUI
import os

// Define window types that can be switched between
enum WindowType: String {
    case main
    case retro
    case archive
    case progress
}

// Window State Controller
class WindowStateController: ObservableObject {
    let container: NSPersistentContainer  // shared container
    
    // Window-specific state
    @Published var activeWindow: WindowType = .main
    @Published var currentLogId: UUID?
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    func switchWindow(to type: WindowType) {
        print("Switching window to: \(type.rawValue)")
        activeWindow = type
        print("Active window is now: \(activeWindow.rawValue)")
    }
    
    func switchToMainView(withLogId logId: UUID) {
        print("Starting switchToMainView: \(logId)")
        currentLogId = logId
        switchWindow(to: .main)
    }
    
    func registerView(_ view: Any, for type: WindowType) {
        print("Registering view for \(type.rawValue)")
        // This function is no longer needed as view instances are managed by the MainView itself
    }
    
    func view(for type: WindowType) -> Any? {
        print("Fetching view for \(type.rawValue)")
        // This function is no longer needed as view instances are managed by the MainView itself
        return nil
    }
}

// Data State Controller 
class DataController: ObservableObject {
    let container: NSPersistentContainer  // same shared container
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reflective", category: "DataController")
    
    // Data-specific operations
    func saveData() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Successfully saved Core Data context")
            } catch {
                logger.error("Error saving context: \(error.localizedDescription)")
                print("Error saving context: \(error)")
            }
        }
    }
    
    func fetchData<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil) -> [T] {
        let request = T.fetchRequest() as! NSFetchRequest<T>
        request.predicate = predicate
        
        do {
            let results = try container.viewContext.fetch(request)
            logger.debug("Fetched \(results.count) records of type \(String(describing: T.self))")
            return results
        } catch {
            logger.error("Error fetching data: \(error.localizedDescription)")
            print("Error fetching data: \(error)")
            return []
        }
    }
    
    init(container: NSPersistentContainer) {
        self.container = container
        
        // Configure autosave
        configureAutosave()
        
        #if DEBUG
        // Add observer for Core Data debug notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextObjectsDidChange),
            name: NSManagedObjectContext.didChangeObjectsNotification,
            object: container.viewContext
        )
        #endif
        
        // Register for app termination notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveOnTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Register for app resign active notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveOnResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        // Register for context did save notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    private func configureAutosave() {
        // Configure context to automatically merge changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure context to merge policy
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up autosave timer
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.container.viewContext.hasChanges {
                self.logger.debug("Autosaving changes")
                self.saveData()
            }
        }
    }
    
    @objc private func saveOnTerminate() {
        logger.debug("Application terminating, saving context")
        saveData()
    }
    
    @objc private func saveOnResignActive() {
        logger.debug("Application resigning active, saving context")
        saveData()
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        // Only process notifications from other contexts
        if notification.object as? NSManagedObjectContext != container.viewContext {
            logger.debug("Background context saved, merging changes to main context")
            container.viewContext.perform {
                self.container.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    #if DEBUG
    @objc private func contextObjectsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !inserts.isEmpty {
            logger.debug("Inserted objects: \(inserts.count)")
        }
        if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updates.isEmpty {
            logger.debug("Updated objects: \(updates.count)")
        }
        if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletes.isEmpty {
            logger.debug("Deleted objects: \(deletes.count)")
        }
    }
    #endif
}
