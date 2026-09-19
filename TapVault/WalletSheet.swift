import SwiftUI
import PassKit

struct WalletSheet: UIViewControllerRepresentable {
    let controller: PKAddPassesViewController
    func makeUIViewController(context: Context) -> PKAddPassesViewController { controller }
    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}
}
