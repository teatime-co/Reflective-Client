import Foundation
import CoreData

// MARK: - Query Extensions
extension Query {
    // MARK: - Convenience properties
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedQueryText: String {
        queryText ?? ""
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    // MARK: - Sorted results property
    var sortedResults: [QueryResult] {
        results?.sortedArray(using: [
            NSSortDescriptor(keyPath: \QueryResult.rank, ascending: true)
        ]) as? [QueryResult] ?? []
    }
    
    // MARK: - Creation method
    static func create(queryText: String, in context: NSManagedObjectContext) -> Query {
        let query = Query(context: context)
        query.id = UUID()
        query.queryText = queryText
        query.createdAt = Date()
        return query
    }
    
    // MARK: - Fetch recent queries
    static var recentQueries: NSFetchRequest<Query> {
        let request = NSFetchRequest<Query>(entityName: "Query")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Query.createdAt, ascending: false)]
        request.fetchLimit = 50
        return request
    }
} 