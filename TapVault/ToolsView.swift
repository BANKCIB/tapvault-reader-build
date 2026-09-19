import SwiftUI
import CardCore

struct ToolsView: View {
    @EnvironmentObject var nfc: NFCService
    let onCreate: () -> Void
    let onReference: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("أدوات وسومك").font(.title.weight(.bold))
                    Text("اختر ما تريد إنجازه.").foregroundStyle(.secondary)
                }
                section("الكتابة", detail: "جهّز المحتوى واحفظه أو اكتبه على وسم.") {
                    ToolButton(title: "تجهيز وسم للكتابة", subtitle: "\(RecordKind.allCases.count) أنواع مرتبة حسب الاستخدام", symbol: "square.and.pencil", action: onCreate)
                        .accessibilityIdentifier("open-writer")
                }
                section("القراءة والفحص", detail: "تعرّف على الشريحة واقرأ محتواها المتاح.") {
                    ToolButton(title: "قراءة بطاقة أو وسم", subtitle: "معلومات الشريحة ورسالة NDEF إن توفرت", symbol: "radiowaves.left.and.right") { nfc.scan() }.disabled(nfc.busy)
                    DisclosureGroup("قراءة متقدمة") {
                        Button { nfc.scanNDEF() } label: {
                            Label("قراءة NDEF مباشرة", systemImage: "doc.text.viewfinder").frame(minHeight: 44)
                        }.disabled(nfc.busy)
                    }.padding(18).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    Label(nfc.status, systemImage: nfc.busy ? "hourglass" : "wave.3.right")
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("nfc-status")
                }
                section("التنظيم", detail: "احتفظ بمعلومات البطاقات والجهات في مكتبتك.") {
                    ToolButton(title: "إضافة مرجع بطاقة", subtitle: "اسم الجهة والملاحظات ورابطها الرسمي", symbol: "bookmark", action: onReference)
                }
                DisclosureGroup("التوافق وطريقة الاستخدام") {
                    VStack(alignment: .leading, spacing: 16) {
                        help("الوسوم القابلة للكتابة", "يفحص التطبيق السعة قبل استبدال رسالة NDEF، ثم يعيد القراءة للتحقق من التطابق.")
                        help("بيانات الأنظمة", "روابط التطبيقات وبيانات JSON وMIME تحتاج إلى قارئ يدعم الصيغة المختارة.")
                        help("المفاتيح والتذاكر", "استخدام بطاقة الفندق أو النقل من الهاتف يحتاج إلى إصدار رقمي رسمي من الجهة.")
                        help("المحفظة", "يمكن فتح ملف بطاقة أصلي من الجهة المصدرة عبر قسم الخزنة.")
                    }.padding(.top, 12)
                }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(Theme.background).navigationTitle("الأدوات").navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func help(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
