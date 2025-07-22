import SwiftUI

struct RetroView: View {
    @EnvironmentObject var dataController: DataController
    
    var body: some View {
        VStack {
            Text("Retro View")
                .font(.largeTitle)
            // Add your retro view specific content here
        }
    }
}

#Preview {
    RetroView()
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
} 