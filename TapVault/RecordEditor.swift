import SwiftUI
import CardCore

struct RecordEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RecordDraft
    let isEditing: Bool
    let onSave: (RecordDraft) -> Void
    private let initialDraft: RecordDraft
    @State private var attempted = false
    @State private var draftsByKind: [RecordKind: RecordDraft] = [:]
    init(draft: RecordDraft, isEditing: Bool = false, onSave: @escaping (RecordDraft) -> Void) {
        _draft = State(initialValue: draft)
        initialDraft = draft
        self.isEditing = isEditing
        self.onSave = onSave
    }
    private var result: Result<TagRecord, Error> {
        Result {
            var value = draft
            if !draft.hasSameFields(as: initialDraft) { value.preserved = nil }
            return try value.makeRecord()
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("نوع البيانات") {
                    Picker("النوع", selection: $draft.kind) {
                        ForEach(RecordGroup.allCases) { group in
                            Section(group.title) {
                                ForEach(group.kinds) { Label($0.title, systemImage: $0.symbol).tag($0) }
                            }
                        }
                    }.pickerStyle(.menu).accessibilityIdentifier("record-kind")
                    Text(draft.kind.explanation).font(.subheadline).foregroundStyle(.secondary)
                    LabeledContent("مثال") {
                        Text(draft.kind.example)
                            .environment(\.layoutDirection, draft.kind.technicalExample ? .leftToRight : .rightToLeft)
                    }.font(.footnote)
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
            .navigationTitle(draft.kind.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "حفظ التعديل" : "إضافة") {
                        attempted = true
                        if case .success(let record) = result { draft.preserved = record; onSave(draft); dismiss() }
                    }.accessibilityIdentifier("confirm-record")
                }
            }
            .onChange(of: draft.kind) { old, new in switchKind(from: old, to: new) }
        }.environment(\.layoutDirection, .rightToLeft).environment(\.locale, Locale(identifier: "ar"))
    }
    private func switchKind(from old: RecordKind, to new: RecordKind) {
        var previous = draft
        previous.kind = old
        draftsByKind[old] = previous
        var next = draftsByKind[new] ?? RecordDraft(id: draft.id)
        next.kind = new
        draft = next
        attempted = false
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
        case .customURI: return "يحتاج هذا الرابط إلى تطبيق قارئ متوافق. الآيفون لا يفتح الروابط المخصصة تلقائيًا من الوسم في الخلفية؛ استخدم رابط موقع https إذا أردت فتح صفحة."
        case .json, .bytes: return "للأنظمة والتطبيقات التي تعرف هذه البيانات. يجب أن يدعم النظام القارئ الصيغة التي تختارها."
        case .sms: return "أبقِ نص الرسالة فارغًا لأفضل توافق مع الآيفون. النص المرفق يحتاج إلى قارئ يدعم صيغة SMS الكاملة؛ الإرسال يتطلب تفاعل المستخدم."
        case .phone, .email: return "يسجل الوسم بيانات الإجراء؛ إجراء مكالمة أو إرسال رسالة يتطلب تفاعل المستخدم وتطبيقًا متوافقًا."
        case .location: return "يُحفظ رابط خرائط بالإحداثيات التي تدخلها، دون طلب الوصول إلى موقعك."
        default: return "الرابط مناسب لفتح موقع على الأجهزة المتوافقة. النص يمكن قراءته من داخل تطبيق يدعم NDEF."
        }
    }
}
