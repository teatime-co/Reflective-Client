import Foundation
import CoreData

extension Log {
    // Convenience properties with type safety
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedContent: String {
        get { content ?? "" }
        set {
            content = newValue
            updatedAt = Date()
        }
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    var wrappedUpdatedAt: Date {
        updatedAt ?? createdAt ?? Date()
    }
    
    // MARK: - Processing status properties
    var isProcessed: Bool {
        processingStatus == "processed"
    }
    
    var needsProcessing: Bool {
        processingStatus == nil || processingStatus == "pending" || processingStatus == "failed"
    }
    
    // MARK: - Tag management with enhanced uniqueness
    var tags: [Tag] {
        let set = self.tagLog ?? []
        let tagAssociationsSet = set as? Set<TagLog> ?? []
        let unsortedTags = tagAssociationsSet.compactMap { $0.tag }
        // Sort tags by name for consistent order
        return unsortedTags.sorted { $0.wrappedName < $1.wrappedName }
    }
    
    func addTag(_ tag: Tag, in context: NSManagedObjectContext) -> Bool {
        guard let _ = TagLog.findOrCreate(tag: tag, log: self, in: context) else {
            print("Failed to create tag association for tag: \(tag.wrappedName)")
            return false
        }
        return true
    }
    
    func removeTag(_ tag: Tag, in context: NSManagedObjectContext) -> Bool {
        return TagLog.remove(tag: tag, log: self, in: context)
    }
    
    // MARK: - Batch tag operations for better performance
    func addTags(_ tags: [Tag], in context: NSManagedObjectContext) -> Int {
        let tagLogPairs = tags.map { ($0, self) }
        let createdAssociations = TagLog.findOrCreateMultiple(tagLogPairs: tagLogPairs, in: context)
        return createdAssociations.count
    }
    
    func removeTags(_ tags: [Tag], in context: NSManagedObjectContext) -> Int {
        let tagLogPairs = tags.map { ($0, self) }
        return TagLog.removeMultiple(tagLogPairs: tagLogPairs, in: context)
    }
    
    func replaceAllTags(with newTags: [Tag], in context: NSManagedObjectContext) {
        // Remove all existing tag associations
        if let existingAssociations = self.tagLog as? Set<TagLog> {
            for association in existingAssociations {
                context.delete(association)
            }
        }
        self.tagLog = NSSet()
        
        // Add new tag associations
        let _ = addTags(newTags, in: context)
    }
    
    // MARK: - Enhanced creation method with better error handling
    static func create(content: String, in context: NSManagedObjectContext) async throws -> Log? {
        let log = Log(context: context)
        log.id = UUID()
        log.content = content
        log.wordCount = Int32(content.components(separatedBy: .whitespacesAndNewlines).count)
        log.processingStatus = "pending"
        let now = Date()
        log.createdAt = now
        log.updatedAt = now
        
        // Process tags with improved batch handling
        let success = log.processTags(in: context)
        
        if !success {
            // If tag processing failed, we can still save the log without tags
            print("Warning: Tag processing failed for log, but log will be saved without tags")
        }
        
        // Save to backend first
        do {
            try await APIClient.shared.createLog(log)
        } catch {
            print("Failed to sync log with backend: \(error)")
            context.delete(log)
            return nil
        }
        
        // Save the context
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved new log with \(log.tags.count) tags")
            } catch {
                print("Failed to save context: \(error)")
                // Clean up the log if save failed
                context.delete(log)
                return nil
            }
        }
        
        return log
    }

    // MARK: - Enhanced tag extraction and processing
    func extractTags() -> [String] {
        guard let content = self.content else { return [] }
        
        // Extract hashtags from the entire content, but ignore escaped hashtags (\#)
        // First, replace all escaped hashtags temporarily with a placeholder
        let escapedContent = content.replacingOccurrences(of: "\\#", with: "ESCAPED_HASHTAG_PLACEHOLDER")
        
        // Now extract all non-escaped hashtags
        let tagPattern = "#([\\w\\d_-]+)"
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [])
        let nsString = escapedContent as NSString
        let matches = regex?.matches(in: escapedContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        let extractedTags = matches.map { match in
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }
        
        // Remove duplicates and empty strings
        return Array(Set(extractedTags.filter { !$0.isEmpty }))
    }
    
    // Enhanced tag processing with batch operations and error handling
    @discardableResult
    func processTags(in context: NSManagedObjectContext) -> Bool {
        // Extract tags from content
        let tagNames = extractTags()
        
        // Create or find tags in batch
        let tags = Tag.findOrCreateMultiple(names: tagNames, in: context)
        
        // Replace all existing tag associations with new ones
        replaceAllTags(with: tags, in: context)
        
        return true
    }
    
    // Enhanced update method with better error handling
    func update(content: String, in context: NSManagedObjectContext) async throws -> Bool {
        let oldContent = self.content
        
        self.content = content
        self.wordCount = Int32(content.components(separatedBy: .whitespacesAndNewlines).count)
        self.updatedAt = Date()
        
        // Reset processing status when content changes
        if self.processingStatus == "processed" {
            self.processingStatus = "pending"
        }
        
        // Process tags with error handling
        let tagProcessingSuccess = self.processTags(in: context)
        if !tagProcessingSuccess {
            print("Warning: Tag processing failed during log update")
            // Revert content if tag processing failed
            self.content = oldContent
            return false
        }
        
        // Sync with backend first
        do {
            try await APIClient.shared.updateLog(self)
        } catch {
            print("Failed to sync log update with backend: \(error)")
            // Revert changes
            self.content = oldContent
            return false
        }
        
        // Save the context
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully updated log with \(self.tags.count) tags")
                return true
            } catch {
                print("Failed to save context during update: \(error)")
                // Revert changes
                self.content = oldContent
                return false
            }
        }
        
        return true
    }
    
    // Get display content with escaped hashtags restored
    func displayContent() -> String {
        guard let content = self.content else { return "" }
        return content.replacingOccurrences(of: "\\#", with: "#")
    }
    
    // MARK: - Enhanced fetch requests
    static var allLogs: NSFetchRequest<Log> {
        let request = NSFetchRequest<Log>(entityName: "Log")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
    
    static func logs(containing searchText: String) -> NSFetchRequest<Log> {
        let request = NSFetchRequest<Log>(entityName: "Log")
        request.predicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
    
    static func logs(for date: Date) -> NSFetchRequest<Log> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request = NSFetchRequest<Log>(entityName: "Log")
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
    
    static func logs(withTag tagName: String) -> NSFetchRequest<Log> {
        let request = NSFetchRequest<Log>(entityName: "Log")
        request.predicate = NSPredicate(
            format: "ANY tagLog.tag.name ==[cd] %@", 
            tagName
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
    
    static func logs(withTags tagNames: [String]) -> NSFetchRequest<Log> {
        let request = NSFetchRequest<Log>(entityName: "Log")
        request.predicate = NSPredicate(
            format: "ANY tagLog.tag.name IN[cd] %@", 
            tagNames
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
    
    // MARK: - Statistics and maintenance
    static func getLogCount(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<Log>(entityName: "Log")
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting logs: \(error)")
            return 0
        }
    }
    
    static func getAverageTagCount(in context: NSManagedObjectContext) -> Double {
        let request = NSFetchRequest<Log>(entityName: "Log")
        
        do {
            let logs = try context.fetch(request)
            let totalTags = logs.reduce(0) { $0 + $1.tags.count }
            return logs.isEmpty ? 0.0 : Double(totalTags) / Double(logs.count)
        } catch {
            print("Error calculating average tag count: \(error)")
            return 0.0
        }
    }
} 
