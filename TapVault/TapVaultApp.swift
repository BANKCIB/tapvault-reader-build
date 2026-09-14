import SwiftUI

@main
@MainActor
struct TapVaultApp: App {
    @StateObject private var store = VaultStore()
    @StateObject private var nfc = NFCService()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ZStack {
                if store.isUnlocked { MainView().environmentObject(store).environmentObject(nfc) }
                else { LockView().environmentObject(store) }
                // The system NFC sheet makes the scene inactive without leaving the app.
                // A real background transition still masks the UI and cancels/locks below.
                if scenePhase == .background || (scenePhase == .inactive && !nfc.busy) {
                    Theme.background.ignoresSafeArea()
                        .overlay(Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(Theme.accent))
                        .accessibilityHidden(true)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
            .tint(Theme.accent)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { nfc.cancel(); nfc.scanned = nil; store.lock() }
            }
        }
    }
}

enum Theme {
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.045, green: 0.075, blue: 0.11, alpha: 1) : UIColor(red: 0.96, green: 0.957, blue: 0.937, alpha: 1) })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.51, green: 0.85, blue: 0.77, alpha: 1) : UIColor(red: 0.08, green: 0.38, blue: 0.34, alpha: 1) })
    static let ink = Color(red: 0.055, green: 0.12, blue: 0.17)
}

struct LockView: View {
    @EnvironmentObject var store: VaultStore
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wave.3.right").font(.system(size: 62, weight: .light)).foregroundStyle(Theme.accent).accessibilityHidden(true)
            Text("قُرب").font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("وسومك ومراجع بطاقاتك،\nفي مساحة تخصك.").font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            if let error = store.errorMessage { Text(error).font(.callout).foregroundStyle(.red).multilineTextAlignment(.center) }
            Button { Task { await store.unlock() } } label: {
                HStack { if store.authenticating { ProgressView() }; Label("فتح الخزنة", systemImage: "faceid") }.frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.borderedProminent).disabled(store.authenticating).accessibilityIdentifier("unlock")
            Label("تخزين محلي مشفر", systemImage: "lock.shield").font(.footnote).foregroundStyle(.secondary)
        }.padding(32).background(Theme.background.ignoresSafeArea())
    }
}
