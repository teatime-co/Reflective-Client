import SwiftUI

struct TagsView: View {
    let tags: [Tag]
    let fontSize: Font
    let showHash: Bool
    
    init(tags: [Tag], fontSize: Font = .caption, showHash: Bool = true) {
        self.tags = tags
        self.fontSize = fontSize
        self.showHash = showHash
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.wrappedId) { tag in
                    Text("\(showHash ? "#" : "")\(tag.wrappedName)")
                        .font(fontSize)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tag.wrappedColor.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    // Create a mock tag for preview
//    let context = NSPersistentContainer(name: "Reflective").viewContext
//    let tag1 = Tag(context: context)
//    tag1.id = UUID()
//    tag1.name = "important"
//    tag1.color = "#FF5733"
//    
//    let tag2 = Tag(context: context)
//    tag2.id = UUID()
//    tag2.name = "work"
//    tag2.color = "#33FF57"
//    
//    TagsView(tags: [tag1, tag2])
//        .frame(height: 50)
}
