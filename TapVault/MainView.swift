import SwiftUI
import CardCore

struct EditorRequest: Identifiable { let id = UUID(); var card: SavedCard?; var reference = false; var kind: RecordKind? }

struct MainView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var nfc: NFCService
    @State private var editor: EditorRequest?
    @State private var alertText: String?
    var body: some View {
        TabView {
            NavigationStack {
                LibraryView(onCreate: { editor = EditorRequest() }, onReference: { editor = EditorRequest(reference: true) })
                    .navigationDestination(for: UUID.self) { id in CardDetailView(id: id) }
            }.tabItem { Label("مكتبتي", systemImage: "square.grid.2x2") }
            NavigationStack {
                WritingHomeView(onCreate: { kind in editor = EditorRequest(kind: kind) })
            }.tabItem { Label("الكتابة", systemImage: "square.and.pencil") }
            NavigationStack { ToolsView(onReference: { editor = EditorRequest(reference: true) }) }
                .tabItem { Label("القراءة", systemImage: "radiowaves.left.and.right") }
            NavigationStack { SettingsView() }.tabItem { Label("الإعدادات", systemImage: "gearshape") }
        }
        .sheet(item: $editor) { request in
            if request.card == nil && !request.reference { WriterView(initialKind: request.kind) }
            else { CardEditor(card: request.card, reference: request.reference) }
        }
        .onReceive(nfc.$scanned) { card in
            guard let card else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard store.isReady, nfc.scanned?.id == card.id else { return }; editor = EditorRequest(card: card)
            }
        }
        .onReceive(nfc.$errorMessage) { if let message = $0 { alertText = message } }
        .onReceive(store.$errorMessage) { if let message = $0 { alertText = message } }
        .onChange(of: nfc.writeSucceeded) { _, success in
            if success { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { alertText = "تمت كتابة البيانات والتحقق من مطابقتها على وسم الوجهة." } }
        }
        .alert("قُرب", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("حسنًا", role: .cancel) { alertText = nil; nfc.errorMessage = nil; store.errorMessage = nil }
        } message: { Text(alertText ?? "") }
    }
}
