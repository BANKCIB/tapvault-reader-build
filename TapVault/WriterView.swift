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
                    Label("جهّز المحتوى، ثم قرّب الوسم", systemImage: "wave.3.right").font(.headline)
                    Text("اجمع رابطًا أو نصًا أو بيانات لنظامك في رسالة واحدة. سيُفحص وسم الوجهة قبل الكتابة.").font(.subheadline).foregroundStyle(.secondary)
                    TextField("اسم البطاقة", text: $title).accessibilityIdentifier("card-title")
                }
                Section {
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
                } header: { HStack { Text("المحتوى · \(records.count) سجل"); Spacer(); EditButton().font(.caption) } }
                Section("قبل الكتابة") {
                    LabeledContent("حجم رسالة NDEF", value: "\(size) بايت").accessibilityIdentifier("message-size")
                    Text("هذا حجم الرسالة مع ترويساتها. يجب أن تتسع لها سعة NDEF التي يعلنها الوسم؛ بعض ذاكرة الشريحة مخصص للنظام.").font(.footnote).foregroundStyle(.secondary)
                    Label("ستُستبدل رسالة الوجهة، ثم تُقرأ للتحقق من التطابق.", systemImage: "checkmark.shield").font(.footnote)
                    Text("معالجة المحتوى تعتمد على الجهاز القارئ وتطبيقاته. وجود عدة سجلات لا يعني تنفيذها جميعًا تلقائيًا.").font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
                Section {
                    Button { writeConfirmation = true } label: { Label("حفظ وكتابة على وسم", systemImage: "wave.3.right").frame(maxWidth: .infinity, minHeight: 44) }
                        .disabled(!ready).accessibilityIdentifier("save-and-write")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("تجهيز وسم").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { discard = true } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ") { save(write: false) }.disabled(!ready).accessibilityIdentifier("save-card") }
            }
            .sheet(item: $draft) { item in
                RecordEditor(draft: item) { value in
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
        }
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

struct RecordEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RecordDraft
    let onSave: (RecordDraft) -> Void
    @State private var attempted = false
    private var result: Result<TagRecord, Error> { Result { var value = draft; value.preserved = nil; return try value.makeRecord() } }
    var body: some View {
        NavigationStack {
            Form {
                Section("نوع البيانات") {
                    Picker("النوع", selection: $draft.kind) { ForEach(RecordKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) } }.pickerStyle(.menu).accessibilityIdentifier("record-kind")
                }
                Section("المحتوى") { fields }
                Section("المعاينة") {
                    switch result {
                    case .success(let record):
                        Text(record.displayValue).font(.callout).textSelection(.enabled).lineLimit(10)
                        LabeledContent("حجم السجل", value: "\(record.encodedByteCount) بايت")
                    case .failure(let error):
                        Text(error.localizedDescription).font(.footnote).foregroundStyle(attempted ? Color.red : Color.secondary)
                    }
                }
                Section { Text(hint).font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("إعداد السجل").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("إضافة") {
                        attempted = true
                        if case .success = result { draft.preserved = nil; onSave(draft); dismiss() }
                    }.accessibilityIdentifier("confirm-record")
                }
            }
            .onChange(of: draft.kind) { _, _ in draft.value = ""; draft.secondary = ""; draft.body = ""; draft.extra = ""; attempted = false }
        }
    }
    @ViewBuilder private var fields: some View {
        switch draft.kind {
        case .text:
            input("النص", "اكتب المحتوى", $draft.value, multiline: true)
        case .url:
            input("الرابط", "https://example.com", $draft.value, keyboard: .URL, technical: true)
        case .phone:
            input("رقم الهاتف", "+966500000000", $draft.value, keyboard: .phonePad, technical: true)
        case .email:
            input("البريد الإلكتروني", "name@example.com", $draft.value, keyboard: .emailAddress, technical: true)
            input("الموضوع — اختياري", "عنوان الرسالة", $draft.secondary)
            input("الرسالة — اختيارية", "محتوى البريد", $draft.body, multiline: true)
        case .sms:
            input("رقم المستلم", "+966500000000", $draft.value, keyboard: .phonePad, technical: true)
            input("الرسالة — اختيارية", "محتوى الرسالة", $draft.body, multiline: true)
        case .location:
            input("خط العرض", "24.7136", $draft.value, keyboard: .numbersAndPunctuation, technical: true)
            input("خط الطول", "46.6753", $draft.secondary, keyboard: .numbersAndPunctuation, technical: true)
        case .contact:
            input("الاسم", "اسم جهة الاتصال", $draft.value)
            input("الهاتف — اختياري", "+966500000000", $draft.secondary, keyboard: .phonePad, technical: true)
            input("البريد — اختياري", "name@example.com", $draft.body, keyboard: .emailAddress, technical: true)
            input("المؤسسة — اختيارية", "اسم المؤسسة", $draft.extra)
        case .customURI:
            input("رابط التطبيق أو النظام", "myapp://item/123", $draft.value, keyboard: .URL, technical: true)
        case .json:
            input("بيانات JSON", "{\"id\":123}", $draft.value, technical: true, multiline: true)
        case .bytes:
            input("نوع MIME", "application/octet-stream", $draft.secondary, technical: true)
            input("المحتوى السداسي عشريًا", "01 A2 FF", $draft.value, technical: true, multiline: true)
        }
    }
    private func input(_ title: String, _ placeholder: String, _ binding: Binding<String>, keyboard: UIKeyboardType = .default, technical: Bool = false, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: binding, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 3...8 : 1...1).keyboardType(keyboard)
                .textInputAutocapitalization(technical ? .never : .sentences).autocorrectionDisabled(technical)
                .environment(\.layoutDirection, technical ? .leftToRight : .rightToLeft)
                .accessibilityLabel(title)
        }
    }
    private var hint: String {
        switch draft.kind {
        case .contact: return "تُحفظ جهة الاتصال بصيغة vCard. قراءتها قد تحتاج إلى تطبيق يدعم هذه الصيغة؛ لا يضيفها الآيفون تلقائيًا عند تقريب الوسم."
        case .json, .bytes, .customURI: return "للأنظمة والتطبيقات التي تعرف هذه البيانات. يجب أن يدعم النظام القارئ الصيغة أو الرابط الذي تختاره."
        case .phone, .sms, .email: return "يسجل الوسم بيانات الإجراء؛ إجراء مكالمة أو إرسال رسالة يتطلب تفاعل المستخدم وتطبيقًا متوافقًا."
        case .location: return "يُحفظ رابط خرائط بالإحداثيات التي تدخلها، دون طلب الوصول إلى موقعك."
        default: return "الرابط مناسب لفتح موقع على الأجهزة المتوافقة. النص يمكن قراءته من داخل تطبيق يدعم NDEF."
        }
    }
}
