import SwiftUI
import CoreData

struct ArchiveView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var windowController: WindowStateController
    @State private var logs: [Log] = []
    @State private var selection: Log.ID?
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Archive")
                .font(.largeTitle)
                .padding()
            
            Table(logs, selection: $selection) {
                TableColumn("Date") { log in
                    Text(log.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")
                }
                .width(150)
                
                TableColumn("Tags") { log in
                    if !log.tags.isEmpty {
                        TagsView(tags: log.tags, fontSize: .caption2, showHash: true)
                    } else {
                        Text("No tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .width(200)
               
                TableColumn("Content") { log in
                    Text(log.content ?? "")
                        .lineLimit(1)
                        .truncationMode(.tail) }
            }
            .onChange(of: selection) { oldValue, newValue in
                if let unwrappedId = newValue.flatMap({ $0 }),  // Unwrap both optionals
                   let selectedLog = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", unwrappedId as CVarArg)).first {
                    print("Selected Log Details:")
                    print("- ID: \(selectedLog.id?.uuidString ?? "Unknown")")
                    print("- Content: \(selectedLog.content ?? "No content")")
                    print("- Created At: \(selectedLog.createdAt?.formatted() ?? "Unknown")")
                    print("- Updated At: \(selectedLog.updatedAt?.formatted() ?? "Unknown")")
                    print("- Tags: \(selectedLog.tags.map { $0.wrappedName }.joined(separator: ", "))")
                } else {
                    print("No log selected or log not found")
                }
            }
            .contextMenu(forSelectionType: Log.ID.self) { _ in
                EmptyView()
            } primaryAction: { items in
                if let selectedId = items.first {
                    windowController.switchToMainView(withLogId: selectedId!)
                }
            }
        }
        .onAppear {
            logs = dataController.fetchData(Log.self, predicate: Log.allLogs.predicate)
        }
    }
}

#Preview {
    ArchiveView()
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
        .frame(width: 800, height: 600)
} 
