import SwiftUI
import CardCore

struct CardEditor: View {
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let original: SavedCard?
    @State private var title: String
    @State private var category: CardCategory
    @State private var notes: String
    @State private var issuerURL: String
    @State private var kind: String
    @State private var content: String
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var errorMessage: String?
    @State private var discard = false
    private var rawRecords: Bool { original.map { $0.records.count > 1 || ($0.records.count == 1 && !$0.canWrite) } ?? false }
    init(card: SavedCard? = nil, reference: Bool = false) {
        original = card
        _title = State(initialValue: card?.title ?? "")
        _category = State(initialValue: card?.category ?? .personal)
        _notes = State(initialValue: card?.notes ?? "")
        _issuerURL = State(initialValue: card?.issuerURL ?? "")
        _kind = State(initialValue: card.map { $0.records.isEmpty ? "reference" : $0.records.first?.uriValue != nil ? "url" : "text" } ?? (reference ? "reference" : "text"))
        _content = State(initialValue: card?.records.first?.displayValue ?? "")
        _hasExpiry = State(initialValue: card?.expiresAt != nil)
        _expiresAt = State(initialValue: card?.expiresAt ?? Date())
    }
    var body: some View {
        NavigationStack {
            Form {
                if let inspection = original?.inspection {
                    Section("نتيجة القراءة") { TagInspectionView(inspection: inspection) }
                }
                Section("البطاقة") {
                    TextField("اسم البطاقة", text: $title).accessibilityIdentifier("card-title")
                    Picker("الفئة", selection: $category) { ForEach(CardCategory.allCases) { Text($0.title).tag($0) } }
                    if original == nil {
                        Picker("المحتوى", selection: $kind) { Text("نص").tag("text"); Text("رابط").tag("url"); Text("مرجع فقط").tag("reference") }
                    }
                }
                if rawRecords, let original {
                    Section("البيانات المقروءة") {
                        ForEach(Array(original.records.enumerated()), id: \.offset) { index, record in
                            VStack(alignment: .leading, spacing: 8) { Text("سجل \(index + 1)").font(.caption); Text(record.displayValue).textSelection(.enabled) }
                        }
                        Text("ستُحفظ السجلات كما قُرئت. الأنواع غير المدعومة للكتابة متاحة للفحص فقط.").font(.footnote).foregroundStyle(.secondary)
                    }
                } else if kind != "reference" {
                    Section(kind == "url" ? "الرابط" : "النص") {
                        if kind == "url" {
                            TextField("https://example.com", text: $content).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().environment(\.layoutDirection, .leftToRight).accessibilityLabel("الرابط الكامل")
                        } else { TextField("المحتوى", text: $content, axis: .vertical).lineLimit(3...10) }
                    }
                } else if original?.inspection == nil {
                    Section { Label("هذا مرجع للمعلومات؛ لا يصدر مفتاح دخول أو تذكرة سفر.", systemImage: "info.circle").font(.callout) }
                }
                Section("تفاصيل اختيارية") {
                    TextField("ملاحظات", text: $notes, axis: .vertical).lineLimit(3...8)
                    TextField("رابط الجهة الرسمي", text: $issuerURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("تاريخ انتهاء مسجل", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("ينتهي في", selection: $expiresAt, displayedComponents: [.date]) }
                }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
                Section { Text("احفظ بيانات الوسوم التي تملكها أو يحق لك استخدامها. بطاقات الدفع خارج نطاق التطبيق.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(original == nil ? "بطاقة جديدة" : "مراجعة البطاقة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { discard = true } }
                ToolbarItem(placement: .confirmationAction) { Button("حفظ", action: save).fontWeight(.semibold).accessibilityIdentifier("save-card") }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("تجاهل التغييرات؟", isPresented: $discard, titleVisibility: .visible) {
                Button("تجاهل", role: .destructive) { dismiss() }; Button("متابعة التعديل", role: .cancel) {}
            }
        }
    }
    private func save() {
        do {
            let records: [TagRecord]
            if rawRecords { records = original?.records ?? [] }
            else if kind == "reference" { records = [] }
            else if let original, content == original.records.first?.displayValue { records = original.records }
            else { records = [try kind == "url" ? TagRecord.uri(content) : TagRecord.text(content)] }
            var card = original ?? SavedCard(title: title)
            card.title = title.trimmingCharacters(in: .whitespacesAndNewlines); card.category = category
            card.notes = notes; card.issuerURL = issuerURL.trimmingCharacters(in: .whitespacesAndNewlines)
            card.records = records; card.expiresAt = hasExpiry ? expiresAt : nil; card.updatedAt = Date()
            try store.save(card); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
