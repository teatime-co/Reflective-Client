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
    
    // Static method to create a new tag or retrieve existing
    static func getOrCreate(name: String, in context: NSManagedObjectContext) -> Tag {
        // Check if tag already exists
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingTag = try? context.fetch(request).first {
            return existingTag
        }
        
        // Create new tag if it doesn't exist
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.createdAt = Date()
        tag.color = Color.random().toHex()
        return tag
    }
    
    // Associate tag with a log
    func associateWithLog(_ log: Log, in context: NSManagedObjectContext) {
        // Check if association already exists
        let request = NSFetchRequest<TagLog>(entityName: "TagLog")
        request.predicate = NSPredicate(format: "tag == %@ AND log == %@", self, log)
        
        if let _ = try? context.fetch(request).first {
            // Association already exists
            return
        }
        
        // Create new association
        let tagLog = TagLog(context: context)
        tagLog.tag = self
        tagLog.log = log
        tagLog.createdAt = Date()
    }
    
    // Fetch all tags
    static var allTags: NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }
}

// Helper extension for Color to generate random colors and convert to/from hex
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