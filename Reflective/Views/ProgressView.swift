import SwiftUI

struct ProgressView: View {
    @EnvironmentObject var dataController: DataController
    
    var body: some View {
        VStack {
            Text("Progress View")
                .font(.largeTitle)
            // Add your progress view specific content here
        }
    }
}

#Preview {
    ProgressView()
        .environmentObject(DataController(container: NSPersistentContainer(name: "Reflective")))
} 