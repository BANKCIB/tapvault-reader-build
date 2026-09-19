import SwiftUI

@main
@MainActor
struct TapVaultApp: App {
    @StateObject private var store = VaultStore()
    @StateObject private var nfc = NFCService()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                if store.isReady {
                    MainView().environmentObject(store).environmentObject(nfc)
                } else {
                    LibraryLoadingView().environmentObject(store)
                }
            }
            .task { store.openLibrary() }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
            .tint(Theme.accent)
            .preferredColorScheme(testColorScheme)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { nfc.cancel(); nfc.scanned = nil }
            }
        }
    }
    private var testColorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--uitesting-dark") { return .dark }
        #endif
        return nil
    }
}

enum Theme {
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.045, green: 0.075, blue: 0.11, alpha: 1) : UIColor(red: 0.96, green: 0.957, blue: 0.937, alpha: 1) })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.51, green: 0.85, blue: 0.77, alpha: 1) : UIColor(red: 0.08, green: 0.38, blue: 0.34, alpha: 1) })
    static let ink = Color(red: 0.055, green: 0.12, blue: 0.17)
}

struct LibraryLoadingView: View {
    @EnvironmentObject var store: VaultStore
    var body: some View {
        VStack(spacing: 20) {
            if let error = store.errorMessage {
                Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle).accessibilityHidden(true)
                Text("تعذر تحميل المكتبة").font(.title2.weight(.bold))
                Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("إعادة المحاولة") { store.openLibrary() }.buttonStyle(.borderedProminent)
            } else {
                ProgressView("تحميل المكتبة…")
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
    }
}
