import SwiftUI
import CoreData

struct ArchiveView: View {
    @EnvironmentObject var dataController: DataController
    @EnvironmentObject var windowController: WindowStateController
    @State private var logs: [Log] = []
    @State private var selection: Log.ID?
    @State private var isLoading = false
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        if dataController.isServerOnlyMode {
            do {
                // Fetch from server
                let serverLogs = try await APIClient.shared.fetchLogs()
                
                // Convert server logs to Core Data models (but don't persist)
                let context = dataController.container.viewContext
                logs = serverLogs.map { payload in
                    let log = Log(context: context)
                    log.id = payload.id
                    log.content = payload.content
                    log.createdAt = payload.createdAt
                    log.updatedAt = payload.updatedAt
                    log.wordCount = payload.wordCount
                    log.processingStatus = payload.processingStatus
                    
                    // Create tags for the log
                    for tagPayload in payload.tags {
                        let tag = Tag(context: context)
                        tag.id = tagPayload.id
                        tag.name = tagPayload.name
                        tag.color = tagPayload.color
                        tag.createdAt = tagPayload.createdAt
                        
                        // Create the association
                        let tagLog = TagLog(context: context)
                        tagLog.tag = tag
                        tagLog.log = log
                        tagLog.createdAt = Date()
                    }
                    
                    return log
                }
                // Don't save the context since we're in server-only mode
            } catch {
                print("Error fetching logs from server: \(error)")
            }
        } else {
            // Use Core Data as before
            logs = dataController.fetchData(Log.self, predicate: Log.allLogs.predicate)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Archive")
                .font(.largeTitle)
                .padding()
            
            if isLoading {
                Text("Loading...")
                    .foregroundColor(.secondary)
            } else {
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
                            .truncationMode(.tail)
                    }
                }
                .onChange(of: selection) { oldValue, newValue in
                    if let unwrappedId = newValue.flatMap({ $0 }),  // Unwrap both optionals
                       let selectedLog = logs.first(where: { $0.id == unwrappedId }) {
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
        }
        .task {
            await loadData()
        }
    }
}

#Preview {
    ArchiveView()
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
        .frame(width: 800, height: 600)
} 
