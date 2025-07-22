import SwiftUI
import AppKit
import CoreData

class LogViewModel: ObservableObject {
    private let dataController: DataController
    
    @Published var currentLogId: UUID?
    @Published var text: String = ""
    @Published var isEditing: Bool = false
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    func loadLogIfNeeded() {
        guard let id = currentLogId,
              let log = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first else {
            return
        }
        text = log.content ?? ""
        isEditing = false
    }
    
    func saveLog() {
        if let id = currentLogId,
           let log = dataController.fetchData(Log.self, predicate: NSPredicate(format: "id == %@", id as CVarArg)).first {
            // Update existing log
            log.update(content: text, in: dataController.container.viewContext)
        } else {
            // Create new log
            let newLog = Log.create(content: text, in: dataController.container.viewContext)
            currentLogId = newLog.id
        }
        isEditing = false
    }
    
    func createNewEntry() {
        currentLogId = nil
        text = ""
        isEditing = true
    }
}

struct MainView: View {
    @EnvironmentObject var windowController: WindowStateController
    @StateObject private var viewModel: LogViewModel
    @Environment(\.colorScheme) var colorScheme
    
    init(dataController: DataController) {
        _viewModel = StateObject(wrappedValue: LogViewModel(dataController: dataController))
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                    Text(viewModel.text)
                        .font(.body)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            HStack {
                if viewModel.currentLogId != nil {
                    Button(action: viewModel.createNewEntry) {
                        Text("New Entry")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.borderless)
                    .padding()
                }
                
                Button(action: {
                    if !viewModel.isEditing {
                        viewModel.isEditing = true
                    } else {
                        viewModel.saveLog()
                    }
                }) {
                    Text(viewModel.isEditing ? "Save" : "Edit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.borderless)
                .padding()
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .onAppear {
            windowController.registerView(self, for: .main)
            viewModel.loadLogIfNeeded()
        }
    }
}

#Preview {
    MainView(dataController: DataController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
} 
