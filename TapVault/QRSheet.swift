import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    private var image: UIImage? {
        guard text.utf8.count <= 1800 else { return nil }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: output.extent.applying(CGAffineTransform(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(28).background(.white, in: RoundedRectangle(cornerRadius: 24)).frame(maxWidth: 340).accessibilityLabel("رمز QR للمحتوى المعروض")
                        Text("اعرض الرمز لمن تريد مشاركة المحتوى معه.").font(.headline).multilineTextAlignment(.center)
                    } else { ContentUnavailableView("المحتوى أطول من حد الرمز", systemImage: "qrcode", description: Text("استخدم المشاركة النصية لهذا السجل.")) }
                    Text(text).textSelection(.enabled).font(.callout).foregroundStyle(.secondary)
                    ShareLink(item: text) { Label("مشاركة المحتوى", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                }.padding(24)
            }.background(Theme.background).navigationTitle("مشاركة سريعة").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } } }
        }
    }
}
