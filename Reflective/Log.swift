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
    
    // Static method to create a new log
    static func create(content: String, in context: NSManagedObjectContext) -> Log {
        let log = Log(context: context)
        log.id = UUID()
        log.content = content
        let now = Date()
        log.createdAt = now
        log.updatedAt = now
        return log
    }
    
    // Update method
    func update(content: String, in context: NSManagedObjectContext) {
        self.content = content
        self.updatedAt = Date()
        
        // Save the context if it's not already being handled by the caller
        if context.hasChanges {
            try? context.save()
        }
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
} 