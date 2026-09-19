import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var nfc: NFCService
    let onReference: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("تعرّف على وسمك").font(.title.weight(.bold))
                    Text("قرّب أعلى الآيفون من الوسم وثبّته حتى تظهر النتيجة.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ToolButton(title: "قراءة بطاقة أو وسم", subtitle: "يعرض نوع الشريحة ومعرّفها، ثم يقرأ المحتوى المتاح إن وُجد.", symbol: "radiowaves.left.and.right") { nfc.scan() }
                    .disabled(nfc.busy).accessibilityIdentifier("inspect-tag")
                Label(nfc.status, systemImage: nfc.busy ? "hourglass" : "wave.3.right")
                    .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("nfc-status")
                DisclosureGroup("قراءة متقدمة") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("قراءة رسالة NDEF مباشرة من وسم قياسي، مثل رابط أو نص.").font(.subheadline).foregroundStyle(.secondary)
                        Button { nfc.scanNDEF() } label: {
                            Label("قراءة NDEF مباشرة", systemImage: "doc.text.viewfinder").frame(minHeight: 44)
                        }.disabled(nfc.busy)
                    }.padding(.top, 8)
                }.padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 12) {
                    Text("بعد القراءة").font(.headline)
                    Text("راجع النتيجة ثم احفظها في مكتبتك. إذا كانت الرسالة قابلة للكتابة، يمكنك كتابتها على وسم آخر متوافق من صفحة تفاصيلها.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("التعرّف على الشريحة يختلف عن قراءة محتواها: قد تظهر معلومات بطاقة لا تحمل رسالة NDEF متاحة.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                ToolButton(title: "إضافة مرجع يدوي", subtitle: "احفظ اسم بطاقة وملاحظاتها ورابط الجهة دون مسحها.", symbol: "bookmark", action: onReference)
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(Theme.background).navigationTitle("القراءة").navigationBarTitleDisplayMode(.inline)
    }
}
