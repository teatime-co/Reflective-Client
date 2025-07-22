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
                } else {
                    print("No log selected or log not found")
                }
            }
            .contextMenu(forSelectionType: Log.ID.self) { _ in
                EmptyView()
            } primaryAction: { items in
                if let selectedId = items.first {
                    windowController.switchWindow(to: .main)
                }
            }
            // .onTableDoubleClick(selection: $selection) { logId in
            //     // NOTE: still not being called
            //     print("Double click detected with row: \(String(describing: logId))")
            //     if let logId = logId {
            //         print("Switching to main view...")
            //         // Switch to main view first
            //         windowController.switchWindow(to: .main)
                    
            //         print("Looking for MainView...")
            //         // Then find the MainView and load the log
            //         if let mainView = windowController.view(for: .main) as? MainView {
            //             print("Found MainView, loading log...")
            //             mainView.loadLog(id: logId)
            //         } else {
            //             print("MainView not found!")
            //         }
            //     }
            // }
        }
        .onAppear {
            // Fetch logs when view appears
            logs = dataController.fetchData(Log.self)
        }
    }
}

#Preview {
    ArchiveView()
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
        .frame(width: 800, height: 600)
} 
