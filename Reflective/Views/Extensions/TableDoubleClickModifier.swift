import SwiftUI

struct TableDoubleClickModifier: ViewModifier {
    let selection: Binding<Log.ID?>
    let action: (UUID?) -> Void
    
    func body(content: Content) -> some View {
        content
            .contextMenu(forSelectionType: UUID.self) { _ in
                EmptyView()
            } primaryAction: { ids in
                if let id = ids.first {
                    action(id)
                }
            }
    }
}

extension View {
    func onTableDoubleClick(selection: Binding<Log.ID?>, perform action: @escaping (UUID?) -> Void) -> some View {
        modifier(TableDoubleClickModifier(selection: selection, action: action))
    }
} 
