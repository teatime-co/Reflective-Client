import Foundation
import CoreData

// MARK: - QueryResult Extensions
extension QueryResult {
    // MARK: - Convenience properties
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedSnippetText: String {
        snippetText ?? ""
    }
    
    var wrappedContextBefore: String {
        contextBefore ?? ""
    }
    
    var wrappedContextAfter: String {
        contextAfter ?? ""
    }
    
    // MARK: - Creation method for backend results
    static func create(
        query: Query,
        log: Log,
        relevanceScore: Double,
        snippetText: String,
        snippetStartIndex: Int32,
        snippetEndIndex: Int32,
        rank: Int32,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        in context: NSManagedObjectContext
    ) -> QueryResult {
        let result = QueryResult(context: context)
        result.id = UUID()
        result.query = query
        result.log = log
        result.relevanceScore = relevanceScore
        result.snippetText = snippetText
        result.snippetStartIndex = snippetStartIndex
        result.snippetEndIndex = snippetEndIndex
        result.rank = rank
        result.contextBefore = contextBefore
        result.contextAfter = contextAfter
        return result
    }
} 