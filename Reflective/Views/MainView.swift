import SwiftUI
import AppKit
import CoreData

@MainActor
class LogViewModel: ObservableObject {
    private let dataController: DataController
    private let apiClient = APIClient.shared
    
    @Published var currentLogId: UUID?
    @Published var text: String = ""
    @Published var displayText: String = ""
    @Published var isEditing: Bool = false
    @Published var tags: [Tag] = []
    @Published var saveError: String?
    @Published var isSaving: Bool = false
    @Published var isLoading: Bool = false
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    func loadLogIfNeeded() async {
        guard let id = currentLogId else {
            print("No log ID provided")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        print("loadLogIfNeeded called with ID: \(String(describing: id))")
        
        if dataController.isServerOnlyMode {
            do {
                // Fetch from server and update/create in memory
                let serverLogs = try await apiClient.fetchLogs()
                if let matchingLog = serverLogs.first(where: { $0.id == id }) {
                    // Use the same context but don't save
                    let context = dataController.container.viewContext
                    
                    // Find or create log
                    let fetchRequest = NSFetchRequest<Log>(entityName: "Log")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    let existingLogs = try context.fetch(fetchRequest)
                    
                    let log: Log
                    if let existingLog = existingLogs.first {
                        log = existingLog
                        // Update properties
                        log.content = matchingLog.content
                        log.updatedAt = matchingLog.updatedAt
                        log.wordCount = matchingLog.wordCount
                        log.processingStatus = matchingLog.processingStatus
                    } else {
                        log = Log(context: context)
                        log.id = matchingLog.id
                        log.content = matchingLog.content
                        log.createdAt = matchingLog.createdAt
                        log.updatedAt = matchingLog.updatedAt
                        log.wordCount = matchingLog.wordCount
                        log.processingStatus = matchingLog.processingStatus
                    }
                    
                    // Update tags
                    // First remove existing tags
                    if let existingTagLogs = log.tagLog as? Set<TagLog> {
                        for tagLog in existingTagLogs {
                            context.delete(tagLog)
                        }
                    }
                    
                    // Add new tags
                    for tagPayload in matchingLog.tags {
                        // Find or create tag
                        let tagFetch = NSFetchRequest<Tag>(entityName: "Tag")
                        tagFetch.predicate = NSPredicate(format: "id == %@", tagPayload.id as CVarArg)
                        let existingTags = try context.fetch(tagFetch)
                        
                        let tag: Tag
                        if let existingTag = existingTags.first {
                            tag = existingTag
                        } else {
                            tag = Tag(context: context)
                            tag.id = tagPayload.id
                            tag.name = tagPayload.name
                            tag.color = tagPayload.color
                            tag.createdAt = tagPayload.createdAt
                        }
                        
                        let tagLog = TagLog(context: context)
                        tagLog.tag = tag
                        tagLog.log = log
                        tagLog.createdAt = Date()
                    }
                    
                    // Update view model
                    text = log.content ?? ""
                    displayText = log.displayContent()
                    tags = log.tags
                    isEditing = false
                    saveError = nil
                    
                    print("Successfully loaded log with \(tags.count) tags")
                } else {
                    print("No log found on server with ID: \(id)")
                }
            } catch {
                print("Error fetching log from server: \(error)")
                saveError = "Failed to load log from server: \(error.localizedDescription)"
            }
        } else {
            // Original Core Data fetching logic
            if let log = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first {
                print("Log found in Core Data")
                text = log.content ?? ""
                displayText = log.displayContent()
                tags = log.tags
                isEditing = false
                saveError = nil
            } else {
                print("No log found in Core Data with ID: \(id)")
            }
        }
    }
    
    func saveLog() async {
        print("Saving log")
        saveError = nil
        isSaving = true
        defer { isSaving = false }
        
        do {
            let context = dataController.container.viewContext
            
            // Find or create log
            let log: Log
            if let id = currentLogId,
               let existingLog = try await context.perform({
                   try context.fetch(NSFetchRequest<Log>(entityName: "Log")).first(where: { $0.id == id })
               }) {
                log = existingLog
                print("Updating existing log: \(id)")
            } else {
                log = Log(context: context)
                log.id = UUID()
                log.createdAt = Date()
                print("Creating new log")
            }
            
            // Update log properties
            log.content = text
            log.updatedAt = Date()
            log.wordCount = Int32(text.split(separator: " ").count)
            log.processingStatus = "pending"
            
            // Process tags
            let success = log.processTags(in: context)
            if !success {
                print("Warning: Tag processing failed")
            }
            
            // Send to server
            if let id = currentLogId {
                // Update existing log
                try await apiClient.updateLog(log)
            } else {
                // Create new log
                try await apiClient.createLog(log)
            }
            
            // Update view model with the log's data
            currentLogId = log.id
            text = log.content ?? ""
            displayText = log.displayContent()
            tags = log.tags
            isEditing = false
            
            // Only save context if not in server-only mode
            if !dataController.isServerOnlyMode {
                try context.save()
            }
            
            print("Successfully saved log with ID: \(log.id?.uuidString ?? "unknown") and \(tags.count) tags")
        } catch {
            saveError = "Failed to sync with server: \(error.localizedDescription)"
            print("Error saving log: \(error)")
        }
    }
    
    func createNewEntry() {
        currentLogId = nil
        text = ""
        displayText = ""
        tags = []
        saveError = nil
        isEditing = true
    }
    
    func clearError() {
        saveError = nil
    }
}

struct MainView: View {
    @EnvironmentObject var windowController: WindowStateController
    @StateObject var viewModel: LogViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var savingDotsState = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    init(dataController: DataController) {
        _viewModel = StateObject(wrappedValue: LogViewModel(dataController: dataController))
    }
    
    private var savingText: String {
        let dots = [".", "..", "..."][savingDotsState]
        return "Saving" + dots
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Error message display
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.clearError()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Tags display
            if !viewModel.isEditing && !viewModel.tags.isEmpty {
                TagsView(tags: viewModel.tags, fontSize: .caption2)
                    .frame(height: 40)
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEditing {
                TextEditor(text: $viewModel.text)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .font(.body)
                    .padding(.horizontal, 20)
                    .overlay(
                        Group {
                            if viewModel.text.isEmpty {
                                HStack {
                                    Text("Start writing...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 24)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                            }
                        }
                    )
            } else {
                ScrollView {
                    Text(viewModel.displayText)
                        .font(.body)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            HStack {
                if viewModel.currentLogId != nil && !viewModel.isEditing {
                    Button(action: viewModel.createNewEntry) {
                        Label("New Entry", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.secondary)
                }
                
                Button(action: {
                    if !viewModel.isEditing {
                        viewModel.isEditing = true
                        viewModel.clearError()
                    } else {
                        Task {
                            await viewModel.saveLog()
                        }
                    }
                }) {
                    Label(viewModel.isEditing ? "Save" : "Edit", 
                          systemImage: viewModel.isEditing ? "checkmark" : "pencil")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(viewModel.isSaving || viewModel.isLoading)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .overlay {
                if viewModel.isSaving {
                    HStack {
                        Spacer()
                        Text(savingText)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .background(.background.opacity(0.8))
                }
            }
            .padding()
        }
        .onAppear {
            if let logId = windowController.currentLogId {
                viewModel.currentLogId = logId
                Task {
                    await viewModel.loadLogIfNeeded()
                }
            }
        }
        .onChange(of: windowController.currentLogId) { oldValue, newValue in
            viewModel.currentLogId = newValue
            Task {
                await viewModel.loadLogIfNeeded()
            }
        }
        .onReceive(timer) { _ in
            if viewModel.isSaving {
                savingDotsState = (savingDotsState + 1) % 3
            }
        }
    }
}

#Preview {
    MainView(dataController: DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
} 
