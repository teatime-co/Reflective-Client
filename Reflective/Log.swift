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
    
    // Get tags associated with this log
    var tags: [Tag] {
        let set = self.tagLog ?? []
        let tagAssociationsSet = set as? Set<TagLog> ?? []
        let unsortedTags = tagAssociationsSet.compactMap { $0.tag }
        // Sort tags by name for consistent order
        return unsortedTags.sorted { $0.wrappedName < $1.wrappedName }
    }
    
    // Extract tags from content
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
        
        return matches.map { match in
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }
    }
    
    // Process and associate tags with this log
    func processTags(in context: NSManagedObjectContext) {
        // Extract tags from anywhere in the content
        let tagNames = extractTags()
        
        // Remove existing tag associations
        if let existingAssociations = self.tagLog as? Set<TagLog> {
            for association in existingAssociations {
                context.delete(association)
            }
        }
        self.tagLog = NSSet()
        
        // Create new tag associations
        for tagName in tagNames {
            let tag = Tag.getOrCreate(name: tagName, in: context)
            tag.associateWithLog(self, in: context)
        }
    }
    
    // Static method to create a new log
    static func create(content: String, in context: NSManagedObjectContext) -> Log {
        let log = Log(context: context)
        log.id = UUID()
        log.content = content
        let now = Date()
        log.createdAt = now
        log.updatedAt = now
        
        // Process tags
        log.processTags(in: context)
        
        // Save the context
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved new log")
            } catch {
                print("Failed to save context: \(error)")
            }
        }
        
        return log
    }
    
    // Update method
    func update(content: String, in context: NSManagedObjectContext) {
        self.content = content
        self.updatedAt = Date()
        
        // Process tags
        self.processTags(in: context)
        
        // Save the context
        if context.hasChanges {
            do {
                try context.save()
                print("Successfully saved log update")
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // Get display content with escaped hashtags restored
    func displayContent() -> String {
        guard let content = self.content else { return "" }
        return content.replacingOccurrences(of: "\\#", with: "#")
    }
    
    // Fetch requests
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
            format: "ANY tagLog.tag.name == %@", 
            tagName
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Log.createdAt, ascending: false)]
        return request
    }
} 
