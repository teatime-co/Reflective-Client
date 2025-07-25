//
//  Persistence.swift
//  Reflective
//
//  Created by Raffy Castillo on 7/21/25.
//

import Foundation
import CoreData
import SwiftUI
import os
import OSLog

// Define window types that can be switched between
enum WindowType: String {
    case main
    case retro
    case archive
    case progress
}

// User Defaults Keys
enum UserDefaultsKeys {
    static let serverOnlyMode = "serverOnlyMode"
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
@MainActor
class DataController: ObservableObject {
    let container: NSPersistentContainer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reflective", category: "DataController")
    private let apiClient = APIClient.shared
    private var syncTask: Task<Void, Never>?
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?
    private var _isServerOnlyMode: Bool = APIClient.isServerOnlyMode
    var isServerOnlyMode: Bool {
        get { _isServerOnlyMode }
        set {
            objectWillChange.send()
            _isServerOnlyMode = newValue
            APIClient.isServerOnlyMode = newValue
        }
    }
    
    init(container: NSPersistentContainer) {
        self.container = container
        startPeriodicSync()
    }
    
    deinit {
        syncTask?.cancel()
    }
    
    // MARK: - Periodic Sync
    private func startPeriodicSync() {
        syncTask = Task {
            while !Task.isCancelled {
                await syncWithBackend()
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 minutes
            }
        }
    }
    
    // MARK: - Data Operations
    func saveData() {
        let context = container.viewContext
        if context.hasChanges && !isServerOnlyMode {
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
        if isServerOnlyMode {
            // In server-only mode, don't fetch from Core Data
            return []
        }
        
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
    
    // MARK: - Search Operations
    func performSearch(query: String) async throws -> [QueryResult] {
        // Create Query object
        let queryObj = Query.create(queryText: query, in: container.viewContext)
        
        do {
            // Perform search on backend
            let searchResponse = try await apiClient.performSearch(query: query)
            
            // Create QueryResults
            var results: [QueryResult] = []
            for (index, result) in searchResponse.results.enumerated() {
                // Find corresponding Log
                let logFetch = NSFetchRequest<Log>(entityName: "Log")
                logFetch.predicate = NSPredicate(format: "id == %@", result.logId as CVarArg)
                
                guard let log = try container.viewContext.fetch(logFetch).first else {
                    continue
                }
                
                let queryResult = QueryResult.create(
                    query: queryObj,
                    log: log,
                    relevanceScore: result.relevanceScore,
                    snippetText: result.snippetText,
                    snippetStartIndex: result.snippetStartIndex,
                    snippetEndIndex: result.snippetEndIndex,
                    rank: Int32(index),
                    contextBefore: result.contextBefore,
                    contextAfter: result.contextAfter,
                    in: container.viewContext
                )
                
                results.append(queryResult)
            }
            
            // Update query metadata
            queryObj.executionTime = searchResponse.executionTime
            queryObj.resultCount = Int32(results.count)
            
            // Save context
            try container.viewContext.save()
            
            return results
            
        } catch {
            // Clean up query object if search failed
            container.viewContext.delete(queryObj)
            try? container.viewContext.save()
            throw error
        }
    }
    
    // MARK: - Data Synchronization
    func syncWithBackend() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        
        do {
            // Fetch all logs from backend
            let remoteLogs = try await apiClient.fetchLogs()
            
            // Keep existing objects in memory but don't save to disk in server-only mode
            for remoteLog in remoteLogs {
                let fetchRequest = NSFetchRequest<Log>(entityName: "Log")
                fetchRequest.predicate = NSPredicate(format: "id == %@", remoteLog.id as CVarArg)
                
                let existingLogs = try container.viewContext.fetch(fetchRequest)
                
                if let existingLog = existingLogs.first {
                    // Update existing log if remote is newer
                    if remoteLog.updatedAt > existingLog.wrappedUpdatedAt {
                        existingLog.content = remoteLog.content
                        existingLog.updatedAt = remoteLog.updatedAt
                        existingLog.wordCount = remoteLog.wordCount
                    }
                } else {
                    // Create new log
                    let newLog = Log(context: container.viewContext)
                    newLog.id = remoteLog.id
                    newLog.content = remoteLog.content
                    newLog.createdAt = remoteLog.createdAt
                    newLog.updatedAt = remoteLog.updatedAt
                    newLog.wordCount = remoteLog.wordCount
                }
            }
            
            // Only save to disk if not in server-only mode
            if !isServerOnlyMode {
                try container.viewContext.save()
            }
            
            // Fetch all tags from backend
            let remoteTags = try await apiClient.fetchTags()
            
            // Sync each tag
            for remoteTag in remoteTags {
                let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
                fetchRequest.predicate = NSPredicate(format: "id == %@", remoteTag.id as CVarArg)
                
                let existingTags = try container.viewContext.fetch(fetchRequest)
                
                if let existingTag = existingTags.first {
                    // Update existing tag if needed
                    existingTag.name = remoteTag.name
                    existingTag.color = remoteTag.color
                } else {
                    // Create new tag
                    let newTag = Tag(context: container.viewContext)
                    newTag.id = remoteTag.id
                    newTag.name = remoteTag.name
                    newTag.color = remoteTag.color
                    newTag.createdAt = remoteTag.createdAt
                }
            }
            
            // Only save to disk if not in server-only mode
            if !isServerOnlyMode {
                try container.viewContext.save()
            }
            
        } catch {
            lastSyncError = error.localizedDescription
            print("Error syncing with backend: \(error)")
        }
        
        isSyncing = false
    }
}
