import Foundation
import CoreData
import SwiftUI

extension Tag {
    // Convenience properties with type safety
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedName: String {
        name ?? ""
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    var wrappedColor: Color {
        if let colorString = color, !colorString.isEmpty {
            return Color(hex: colorString)
        }
        return .blue
    }
    
    // MARK: - Static method to create a new tag or retrieve existing
    static func findOrCreate(name: String, in context: NSManagedObjectContext) -> Tag {
        // Check if tag already exists
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        
        if let existingTag = try? context.fetch(request).first {
            return existingTag
        }
        
        // Create new tag if it doesn't exist
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.createdAt = Date()
        tag.color = Color.random().toHex()
        return tag
    }
    
    // MARK: - Batch creation with uniqueness checking
    static func findOrCreateMultiple(names: [String], in context: NSManagedObjectContext) -> [Tag] {
        // Normalize and deduplicate names
        let normalizedNames = Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.isEmpty }
        
        // Create array to store all tags
        var tags: [Tag] = []
        
        // Process each name
        for name in normalizedNames {
            tags.append(findOrCreate(name: name, in: context))
        }
        
        return tags
    }
    
    // MARK: - Computed property for associated logs
    var logs: [Log] {
        let set = self.tagLog ?? []
        let tagAssociationsSet = set as? Set<TagLog> ?? []
        return tagAssociationsSet.compactMap { $0.log }
    }
    
    // MARK: - Associate tag with a log
    func associateWithLog(_ log: Log, in context: NSManagedObjectContext) {
        // Use the robust TagLog.findOrCreate method
        _ = TagLog.findOrCreate(tag: self, log: log, in: context)
    }
    
    // MARK: - Fetch all tags
    static var allTags: NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }
    
    // MARK: - Search tags by name pattern
    static func tags(matchingPattern pattern: String) -> NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", pattern)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }
}

// MARK: - Helper extension for Color to generate random colors and convert to/from hex
extension Color {
    static func random() -> Color {
        Color(
            red: .random(in: 0.2...0.9),
            green: .random(in: 0.2...0.9),
            blue: .random(in: 0.2...0.9)
        )
    }
    
    func toHex() -> String {
        let uiColor = NSColor(self)
        guard let components = uiColor.cgColor.components else { return "" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 