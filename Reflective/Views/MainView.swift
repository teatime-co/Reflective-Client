import SwiftUI
import AppKit
import CoreData

@MainActor
class LogViewModel: ObservableObject {
    private let dataController: DataController
    
    @Published var currentLogId: UUID?
    @Published var text: String = ""
    @Published var displayText: String = ""
    @Published var isEditing: Bool = false
    @Published var tags: [Tag] = []
    @Published var saveError: String?
    @Published var isSaving: Bool = false
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    func loadLogIfNeeded() {
        print("loadLogIfNeeded called with ID: \(String(describing: currentLogId))")
        guard let id = currentLogId,
              let log = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first else {
            print("No log found or ID is nil")
            return
        }
        print("Log found, updating text")
        text = log.content ?? ""
        displayText = log.displayContent()
        tags = log.tags
        isEditing = false
        saveError = nil
    }
    
    func saveLog() async {
        print("Saving log")
        saveError = nil
        isSaving = true
        defer { isSaving = false }
        
        do {
            if let id = currentLogId,
               let log = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first {
                print("Updating existing log: \(id)")
                
                let success = try await log.update(content: text, in: dataController.container.viewContext)
                if success {
                    tags = log.tags // Update tags after successful save
                    displayText = log.displayContent() // Update display text
                    print("Successfully updated log with \(tags.count) tags")
                    isEditing = false
                } else {
                    saveError = "Failed to update log. Please try again."
                    print("Failed to update log")
                }
            } else {
                print("Creating new log")
                
                if let newLog = try await Log.create(content: text, in: dataController.container.viewContext) {
                    currentLogId = newLog.id
                    tags = newLog.tags // Update tags after successful save
                    displayText = newLog.displayContent() // Update display text
                    print("New log created with ID: \(String(describing: newLog.id)) and \(tags.count) tags")
                    isEditing = false
                } else {
                    saveError = "Failed to create new log. Please try again."
                    print("Failed to create new log")
                }
            }
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
    
    init(dataController: DataController) {
        _viewModel = StateObject(wrappedValue: LogViewModel(dataController: dataController))
    }
    
    private var savingText: String {
        "Saving" + String(repeating: ".", count: savingDotsState + 1)
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
            
            if viewModel.isEditing {
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
                
                if viewModel.isSaving {
                    Text(savingText)
                        .foregroundStyle(.secondary)
                        .onAppear {
                            // Start the timer when saving begins
                            let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                                savingDotsState = (savingDotsState + 1) % 3
                                // Stop the timer when saving is complete
                                if !viewModel.isSaving {
                                    timer.invalidate()
                                    savingDotsState = 0
                                }
                            }
                            // Make sure the timer stops if the view disappears
                            RunLoop.current.add(timer, forMode: .common)
                        }
                } else {
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
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding()
        }
        .onAppear {
            if let logId = windowController.currentLogId {
                viewModel.currentLogId = logId
                viewModel.loadLogIfNeeded()
            }
        }
        .onChange(of: windowController.currentLogId) { oldValue, newValue in
            viewModel.currentLogId = newValue
            viewModel.loadLogIfNeeded()
        }
    }
}

#Preview {
    MainView(dataController: DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
} 
