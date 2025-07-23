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
            }
            .padding()
            
            // Content based on active window
            switch windowController.activeWindow {
            case .main:
                if let mainView = windowController.view(for: .main) as? MainView {
                    mainView
                }
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
    ContentView()
        .environmentObject(WindowStateController(container: NSPersistentContainer(name: "Reflective")))
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
}
