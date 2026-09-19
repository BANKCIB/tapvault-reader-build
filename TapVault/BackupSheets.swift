import SwiftUI
import CardCore

struct BackupExportSheet: View {
    let package: BackupPackage
    @Environment(\.dismiss) private var dismiss
    @State private var keySaved = false
    @State private var exporting = false
    @State private var feedback: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("احفظ رمز الاستعادة أولًا").font(.title2.weight(.bold))
                    Text("هذا الرمز يفتح هذه النسخة فقط. لا يمكن استعادتها إذا فُقد، ولا ينبغي حفظه بجانب ملفها.")
                    Text(package.recoveryKey).font(.body.monospaced()).textSelection(.enabled).environment(\.layoutDirection, .leftToRight)
                    Button("نسخ الرمز لمدة دقيقتين") {
                        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: package.recoveryKey]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                        feedback = "نُسخ الرمز. احفظه في مدير كلمات المرور."
                    }.frame(minHeight: 44)
                    Toggle("حفظت الرمز في مكان آمن", isOn: $keySaved)
                }
                Section {
                    Button("حفظ ملف النسخة") { exporting = true }.disabled(!keySaved).frame(minHeight: 44)
                    if let feedback { Text(feedback).font(.footnote).foregroundStyle(.secondary) }
                }
            }.navigationTitle("نسخة مشفرة").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } } }
                .fileExporter(isPresented: $exporting, document: BackupDocument(data: package.data), contentType: .tapVaultBackup, defaultFilename: "TapVault-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))") { result in
                    switch result { case .success: feedback = "حُفظت النسخة المشفرة بنجاح."; case .failure(let error): feedback = error.localizedDescription }
                }
        }
    }
}

struct BackupRestoreSheet: View {
    let package: RestorePackage
    @EnvironmentObject var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var feedback: String?
    @State private var restored = false
    var body: some View {
        NavigationStack {
            Form {
                Section("رمز الاستعادة") {
                    SecureField("ألصق رمز هذه النسخة", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled().environment(\.layoutDirection, .leftToRight)
                    Text("يُدمج المحتوى بعد التحقق من سلامته. لن تُستبدل البطاقات الموجودة.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("فك التشفير والاستعادة") {
                        do {
                            let cards = try BackupCodec.open(package.data, recoveryKey: key)
                            let count = try store.merge(cards); feedback = "تمت إضافة \(count) بطاقة. جرى تجاوز البطاقات المكررة."; restored = true; key = ""
                        } catch { feedback = "تعذرت الاستعادة. تحقق من الرمز وسلامة الملف. لم تتغير خزنتك." }
                    }.disabled(key.isEmpty || restored).frame(minHeight: 44)
                    if let feedback { Text(feedback).foregroundStyle(restored ? Theme.accent : .red) }
                }
            }.navigationTitle("استعادة الخزنة").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } } }
        }
    }
}
