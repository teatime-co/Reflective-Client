import Foundation
import CoreData

// MARK: - TagLog Extensions with Enhanced Programmatic Uniqueness
extension TagLog {
    
    // MARK: - Enhanced find or create association with error handling
    static func findOrCreate(tag: Tag, log: Log, in context: NSManagedObjectContext) -> TagLog? {
        // Validate inputs
        guard tag.managedObjectContext != nil, log.managedObjectContext != nil else {
            print("Error: Tag or Log not properly managed by CoreData context")
            return nil
        }
        
        // Check if relationship already exists
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == %@ AND log == %@", tag, log)
        request.fetchLimit = 1
        
        do {
            let existingAssociations = try context.fetch(request)
            if let existing = existingAssociations.first {
                return existing
            }
        } catch {
            print("Error searching for existing TagLog association: \(error)")
            return nil
        }
        
        // Create new relationship
        let tagLog = TagLog(context: context)
        tagLog.tag = tag
        tagLog.log = log
        tagLog.createdAt = Date()
        
        return tagLog
    }
    
    // MARK: - Batch create associations with uniqueness checking
    static func findOrCreateMultiple(
        tagLogPairs: [(Tag, Log)], 
        in context: NSManagedObjectContext
    ) -> [TagLog] {
        guard !tagLogPairs.isEmpty else { return [] }
        
        // Create a set of existing associations to check against
        var existingAssociations: Set<String> = Set()
        var allTagLogs: [TagLog] = []
        
        // Build predicates for batch fetching existing associations
        let predicates = tagLogPairs.map { tag, log in
            NSPredicate(format: "tag == %@ AND log == %@", tag, log)
        }
        
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = compoundPredicate
        
        do {
            let existing = try context.fetch(request)
            for tagLog in existing {
                if let tag = tagLog.tag, let log = tagLog.log {
                    let key = "\(tag.objectID)_\(log.objectID)"
                    existingAssociations.insert(key)
                    allTagLogs.append(tagLog)
                }
            }
        } catch {
            print("Error fetching existing TagLog associations: \(error)")
        }
        
        // Create new associations for pairs that don't exist
        for (tag, log) in tagLogPairs {
            let key = "\(tag.objectID)_\(log.objectID)"
            if !existingAssociations.contains(key) {
                let tagLog = TagLog(context: context)
                tagLog.tag = tag
                tagLog.log = log
                tagLog.createdAt = Date()
                allTagLogs.append(tagLog)
            }
        }
        
        return allTagLogs
    }
    
    // MARK: - Safe remove association
    static func remove(tag: Tag, log: Log, in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == %@ AND log == %@", tag, log)
        
        do {
            let associations = try context.fetch(request)
            for tagLog in associations {
                context.delete(tagLog)
            }
            return !associations.isEmpty
        } catch {
            print("Error removing TagLog association: \(error)")
            return false
        }
    }
    
    // MARK: - Batch remove associations
    static func removeMultiple(
        tagLogPairs: [(Tag, Log)], 
        in context: NSManagedObjectContext
    ) -> Int {
        guard !tagLogPairs.isEmpty else { return 0 }
        
        let predicates = tagLogPairs.map { tag, log in
            NSPredicate(format: "tag == %@ AND log == %@", tag, log)
        }
        
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = compoundPredicate
        
        do {
            let associations = try context.fetch(request)
            for tagLog in associations {
                context.delete(tagLog)
            }
            return associations.count
        } catch {
            print("Error removing TagLog associations: \(error)")
            return 0
        }
    }
    
    // MARK: - Check if association exists
    static func exists(tag: Tag, log: Log, in context: NSManagedObjectContext) -> Bool {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == %@ AND log == %@", tag, log)
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking TagLog association existence: \(error)")
            return false
        }
    }
    
    // MARK: - Fetch all tags for a specific log
    static func tagsForLog(_ log: Log) -> NSFetchRequest<TagLog> {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "log == %@", log)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TagLog.createdAt, ascending: true)]
        return request
    }
    
    // MARK: - Fetch all logs for a specific tag
    static func logsForTag(_ tag: Tag) -> NSFetchRequest<TagLog> {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == %@", tag)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TagLog.createdAt, ascending: false)]
        return request
    }
    
    // MARK: - Get association count for performance monitoring
    static func getAssociationCount(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting TagLog associations: \(error)")
            return 0
        }
    }
    
    // MARK: - Clean up orphaned associations (maintenance)
    static func cleanupOrphanedAssociations(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == nil OR log == nil")
        
        do {
            let orphaned = try context.fetch(request)
            for tagLog in orphaned {
                context.delete(tagLog)
            }
            return orphaned.count
        } catch {
            print("Error cleaning up orphaned TagLog associations: \(error)")
            return 0
        }
    }
} 