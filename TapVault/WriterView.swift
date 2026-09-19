import SwiftUI
import CardCore

struct WriterView: View {
    @EnvironmentObject var store: VaultStore
    @EnvironmentObject var nfc: NFCService
    @Environment(\.dismiss) private var dismiss
    let original: SavedCard?
    @State private var title: String
    @State private var records: [RecordDraft]
    @State private var draft: RecordDraft?
    @State private var errorMessage: String?
    @State private var discard = false
    @State private var writeConfirmation = false
    init(card: SavedCard? = nil) {
        original = card
        _title = State(initialValue: card?.title ?? "")
        _records = State(initialValue: card?.records.map { RecordDraft(record: $0) } ?? [])
    }
    private var size: Int { records.compactMap { try? $0.makeRecord() }.reduce(0) { $0 + $1.encodedByteCount } }
    private var ready: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !records.isEmpty && !nfc.busy }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("اسم الوسم", text: $title).accessibilityIdentifier("card-title")
                } header: { Text("اسم الوسم") } footer: {
                    Text("اسم يساعدك على العثور على هذا المحتوى في مكتبتك.")
                }
                Section {
                    if records.isEmpty {
                        Label("أضف رابطًا أو نصًا أو بيانات أخرى للبدء.", systemImage: "doc.badge.plus")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(records) { item in
                        Button { draft = item } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.kind.symbol).foregroundStyle(Theme.accent).frame(width: 28)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.kind.title).font(.headline).foregroundStyle(.primary)
                                    Text((try? item.makeRecord().displayValue) ?? "").font(.caption).lineLimit(2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\((try? item.makeRecord().encodedByteCount) ?? 0) بايت").font(.caption).foregroundStyle(.secondary)
                            }.frame(minHeight: 44)
                        }.contextMenu {
                            Button("تحرير") { draft = item }
                            Button("تحريك لأعلى") { move(item.id, by: -1) }.disabled(records.first?.id == item.id)
                            Button("تحريك لأسفل") { move(item.id, by: 1) }.disabled(records.last?.id == item.id)
                            Button("حذف السجل", role: .destructive) { records.removeAll { $0.id == item.id } }
                        }
                    }.onDelete { records.remove(atOffsets: $0) }.onMove { records.move(fromOffsets: $0, toOffset: $1) }
                    Button { draft = RecordDraft() } label: { Label("إضافة سجل", systemImage: "plus.circle.fill").frame(minHeight: 44) }
                        .disabled(records.count >= 32).accessibilityIdentifier("add-record")
                } header: { HStack { Text("المحتوى · \(records.count) سجل"); Spacer(); if !records.isEmpty { EditButton().font(.caption).frame(minWidth: 44, minHeight: 44) } } }
                Section("ملخص الكتابة") {
                    LabeledContent("حجم رسالة NDEF", value: "\(size) بايت").accessibilityIdentifier("message-size")
                    Label("ستُستبدل رسالة الوجهة، ثم تُقرأ للتحقق من التطابق.", systemImage: "checkmark.shield").font(.footnote)
                    DisclosureGroup("السعة والتوافق") {
                        Text("هذا حجم الرسالة مع ترويساتها. يجب أن تتسع لها سعة NDEF التي يعلنها الوسم؛ بعض ذاكرة الشريحة مخصص للنظام.").font(.footnote).foregroundStyle(.secondary)
                        Text("معالجة المحتوى تعتمد على الجهاز القارئ وتطبيقاته. وجود عدة سجلات لا يعني تنفيذها جميعًا تلقائيًا.").font(.footnote).foregroundStyle(.secondary)
                    }

                }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
                Section {
                    Button { writeConfirmation = true } label: { Label("حفظ وكتابة على وسم", systemImage: "wave.3.right").frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.borderedProminent).disabled(!ready).accessibilityIdentifier("save-and-write")
                } footer: { Text("زر «حفظ» في الأعلى يحفظ المحتوى في مكتبتك دون الكتابة على وسم.") }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("تجهيز وسم").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { discard = true } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") { save(write: false) }.disabled(!ready).accessibilityIdentifier("save-card") }
            }
            .sheet(item: $draft) { item in
                RecordEditor(draft: item, isEditing: records.contains { $0.id == item.id }) { value in
                    if let index = records.firstIndex(where: { $0.id == value.id }) { records[index] = value }
                    else { records.append(value) }
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("تجاهل التغييرات؟", isPresented: $discard, titleVisibility: .visible) {
                Button("تجاهل", role: .destructive) { dismiss() }; Button("متابعة التعديل", role: .cancel) {}
            }
            .confirmationDialog("استبدال محتوى وسم الوجهة بهذه الرسالة؟", isPresented: $writeConfirmation, titleVisibility: .visible) {
                Button("حفظ وبدء الكتابة") { save(write: true) }; Button("إلغاء", role: .cancel) {}
            }
        }.environment(\.layoutDirection, .rightToLeft).environment(\.locale, Locale(identifier: "ar"))
    }
    private func save(write: Bool) {
        do {
            var card = original ?? SavedCard(title: title)
            card.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            card.records = try records.map { try $0.makeRecord() }; card.updatedAt = Date()
            try card.validate(); try store.save(card)
            dismiss()
            if write { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if store.isUnlocked { nfc.write(card) } } }
        } catch { errorMessage = error.localizedDescription }
    }
    private func move(_ id: UUID, by offset: Int) {
        guard let index = records.firstIndex(where: { $0.id == id }), records.indices.contains(index + offset) else { return }
        records.swapAt(index, index + offset)
    }
}
