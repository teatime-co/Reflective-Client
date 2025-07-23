//
//  ContentView.swift
//  Reflective
//
//  Created by Raffy Castillo on 7/22/25.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var windowController: WindowStateController
    @EnvironmentObject var dataController: DataController
    @Environment(\.managedObjectContext) var viewContext

    var body: some View {
        VStack {
            HStack {
                Button(action: { windowController.switchWindow(to: .main) }) {
                    Label("Write", systemImage: "pencil.and.scribble")
                }
                .buttonStyle(.borderedProminent)
                .tint(windowController.activeWindow == .main ? .accentColor : .secondary)
                
                Button(action: { windowController.switchWindow(to: .retro) }) {
                    Label("Retro", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .tint(windowController.activeWindow == .retro ? .accentColor : .secondary)
                
                Button(action: { windowController.switchWindow(to: .archive) }) {
                    Label("Archive", systemImage: "archivebox")
                }
                .buttonStyle(.borderedProminent)
                .tint(windowController.activeWindow == .archive ? .accentColor : .secondary)
                
                Button(action: { windowController.switchWindow(to: .progress) }) {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(windowController.activeWindow == .progress ? .accentColor : .secondary)
            }
            .padding()
            
            // Content based on active window
            switch windowController.activeWindow {
            case .main:
                MainView(dataController: dataController)
            case .retro:
                RetroView()
            case .archive:
                ArchiveView()
            case .progress:
                ProgressView()
            }
            
            Spacer()
        }
    }
}

#Preview {
    let container = NSPersistentContainer(name: "Reflective")
    return ContentView()
        .environmentObject(WindowStateController(container: container))
        .environmentObject(DataController(container: container))
        .environment(\.managedObjectContext, container.viewContext)
}
