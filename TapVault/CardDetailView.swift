import SwiftUI
import CardCore

struct CardDetailView: View {
    let id: UUID
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var nfc: NFCService
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var deleting = false
    @State private var writing = false
    @State private var editingContent = false
    @State private var qrText: String?
    var body: some View {
        Group {
            if let card = store.cards.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary(card)
                        if let inspection = card.inspection {
                            TagInspectionView(inspection: inspection)
                                .padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                        }
                        if !card.records.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack { Text("البيانات المحفوظة").font(.headline); Spacer(); Text("\(card.encodedByteCount) بايت").font(.caption).foregroundStyle(.secondary) }
                                ForEach(Array(card.records.enumerated()), id: \.offset) { index, record in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("سجل \(index + 1)").font(.caption).foregroundStyle(.secondary)
                                        Text(record.displayValue).font(.body).textSelection(.enabled)
                                        if record.isWritableContent {
                                            HStack {
                                                ShareLink(item: record.displayValue) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                                                Spacer()
                                                Button { qrText = record.displayValue } label: { Label("رمز QR", systemImage: "qrcode") }
                                            }.font(.subheadline).frame(minHeight: 44)
                                        }
                                        DisclosureGroup("البيانات التقنية") {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("TNF: \(record.tnf)")
                                                Text("Type: \(record.type.map { String(format: "%02x", $0) }.joined())")
                                                Text("Payload: \(record.payload.count) bytes")
                                                Text(record.payload.map { String(format: "%02x", $0) }.joined(separator: " ")).textSelection(.enabled)
                                            }.font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading).environment(\.layoutDirection, .leftToRight)
                                        }.font(.footnote)
                                    }
                                    if index < card.records.count - 1 { Divider() }
                                }
                            }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                        }
                        if card.canWrite {
                            Button { writing = true } label: { Label("كتابة على وسم آخر", systemImage: "wave.3.right").frame(maxWidth: .infinity).padding(.vertical, 10) }
                                .buttonStyle(.borderedProminent).disabled(nfc.busy)
                            Button { editingContent = true } label: { Label("تحرير سجلات الكتابة", systemImage: "square.and.pencil").frame(minHeight: 44) }.accessibilityIdentifier("edit-records")
                            Text("يكتب سجلات NDEF المحفوظة بعد فحص سعة الوجهة. يمكنك تكرار الكتابة على وسم آخر من هذه الصفحة.").font(.footnote).foregroundStyle(.secondary)
                        } else if card.inspection == nil || !card.records.isEmpty {
                            Label(card.records.isEmpty ? "مرجع محفوظ. اطلب المفتاح أو التذكرة الرقمية من جهة الإصدار." : "هذه السجلات محفوظة للفحص، وليست ضمن أنواع الكتابة المتاحة.", systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                        }
                        if !card.notes.isEmpty { detailBlock("ملاحظاتي", card.notes) }
                        if let url = URL(string: card.issuerURL), !card.issuerURL.isEmpty { Link(destination: url) { Label("فتح موقع جهة الإصدار", systemImage: "arrow.up.forward.app").frame(minHeight: 44) } }
                        VStack(spacing: 14) {
                            LabeledContent("المصدر", value: card.source)
                            LabeledContent("تاريخ الحفظ", value: card.createdAt.formatted(date: .abbreviated, time: .omitted))
                            if let capacity = card.capacity { LabeledContent("سعة NDEF", value: "\(capacity) بايت") }
                            if let writable = card.sourceWritable { LabeledContent("الوسم عند القراءة", value: writable ? "قابل للكتابة" : "للقراءة فقط") }
                            if let expiry = card.expiresAt { LabeledContent("التاريخ المسجل", value: expiry.formatted(date: .abbreviated, time: .omitted)) }
                            if let fingerprint = card.fingerprint { DisclosureGroup("بصمة البيانات") { Text(fingerprint).font(.caption.monospaced()).textSelection(.enabled).environment(\.layoutDirection, .leftToRight) } }
                        }.font(.footnote).padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                        Button(role: .destructive) { deleting = true } label: { Label("حذف البطاقة", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 48) }
                    }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }.background(Theme.background)
                .navigationTitle(card.category.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("تعديل") { editing = true } }
                .sheet(isPresented: $editing) { CardEditor(card: card) }
                .sheet(isPresented: $editingContent) { WriterView(card: card) }
                .sheet(isPresented: Binding(get: { qrText != nil }, set: { if !$0 { qrText = nil } })) { QRSheet(text: qrText ?? "") }
                .confirmationDialog("ستستبدل هذه العملية بيانات وسم الوجهة. استخدم وسمًا تملكه وقابلًا للكتابة.", isPresented: $writing, titleVisibility: .visible) {
                    Button("بدء الكتابة") { nfc.write(card) }; Button("إلغاء", role: .cancel) {}
                }
                .confirmationDialog("حذف هذه البطاقة من خزنتك؟", isPresented: $deleting, titleVisibility: .visible) {
                    Button("حذف", role: .destructive) { do { try store.delete(id); dismiss() } catch { store.errorMessage = error.localizedDescription } }
                    Button("إلغاء", role: .cancel) {}
                }
            } else { ContentUnavailableView("البطاقة غير موجودة", systemImage: "doc.questionmark") }
        }
    }
    private func summary(_ card: SavedCard) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: card.category.symbol).font(.largeTitle).foregroundStyle(Theme.accent).accessibilityHidden(true)
                Spacer()
                Button { store.toggleFavorite(card) } label: { Image(systemName: card.favorite ? "star.fill" : "star").font(.title3).frame(width: 44, height: 44) }
                    .accessibilityLabel(card.favorite ? "إزالة من المفضلة" : "إضافة للمفضلة")
            }
            Text(card.title).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Label(card.capability, systemImage: card.canWrite ? "checkmark.circle" : "bookmark").font(.subheadline).foregroundStyle(Theme.accent)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 26))
    }
    private func detailBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); Text(text).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
