import SwiftUI
import UniformTypeIdentifiers
import PassKit
import CardCore

extension UTType { static let tapVaultBackup = UTType(exportedAs: "com.m7madv.tapvault.backup", conformingTo: .data) }

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.tapVaultBackup, .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents, bytes.count <= BackupCodec.maximumBytes else { throw CardError.tooLarge }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupPackage: Identifiable { let id = UUID(); let data: Data; let recoveryKey: String }
struct RestorePackage: Identifiable { let id = UUID(); let data: Data }
struct WalletPackage: Identifiable { let id = UUID(); let controller: PKAddPassesViewController }

struct SettingsView: View {
    @EnvironmentObject var store: VaultStore
    @State private var exported: BackupPackage?
    @State private var restore: RestorePackage?
    @State private var wallet: WalletPackage?
    @State private var importing = false
    @State private var importingWallet = false
    @State private var alertText: String?
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "lock.shield").font(.largeTitle).foregroundStyle(Theme.accent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) { Text("خزنتك الشخصية").font(.headline); Text("محلية. مشفرة. تحت تحكمك.").font(.subheadline).foregroundStyle(.secondary) }
                }.padding(.vertical, 12)
                LabeledContent("البطاقات المحفوظة", value: "\(store.cards.count)")
                Button { store.lock() } label: { Label("قفل الآن", systemImage: "lock") }.frame(minHeight: 44)
            }
            Section {
                Button { createBackup() } label: { Label("إنشاء نسخة مشفرة", systemImage: "arrow.up.doc") }.frame(minHeight: 44).accessibilityIdentifier("create-backup")
                Button { importingWallet = false; importing = true } label: { Label("استعادة نسخة مشفرة", systemImage: "arrow.down.doc") }.frame(minHeight: 44)
            } header: { Text("النسخ الاحتياطي") } footer: {
                Text("لكل نسخة رمز استعادة مستقل. احتفظ به خارج ملف النسخة. الاستعادة تدمج البطاقات وتتجاوز المكررات دون استبدال ما لديك.")
            }
            Section {
                Button { importingWallet = true; importing = true } label: { Label("فتح بطاقة من جهة الإصدار", systemImage: "wallet.pass") }.frame(minHeight: 44)
                Text("اختر ملفًا أصليًا بصيغة .pkpass. يحدد النظام والجهة المصدرة إمكانية إضافته. بعض مفاتيح الفنادق وبطاقات النقل تُضاف فقط من تطبيق الجهة.").font(.footnote).foregroundStyle(.secondary)
            } header: { Text("Apple Wallet") }
            Section("الخصوصية") {
                Label("لا يوجد حساب أو خادم للتطبيق", systemImage: "externaldrive")
                Label("تشفير البيانات والنسخ باستخدام AES-GCM", systemImage: "lock.doc")
                Label("مفتاح الجهاز محفوظ في Keychain", systemImage: "key")
                Label("قفل عند الانتقال إلى الخلفية", systemImage: "app.badge.checkmark")
                Text("مشاركة سجل نصي أو رمز QR تكشف ذلك السجل لمن ترسله إليه. لا توجد مزامنة سحابية تلقائية. حذف التطبيق قد يفقد البيانات؛ احتفظ بنسخة مشفرة ورمزها.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("عن هذه النسخة") {
                LabeledContent("الإصدار", value: "1.0 · شخصي")
                Text("التطبيق قارئ ومنظم لبيانات NFC القياسية. لا يستخرج مفاتيح البطاقات المحمية، ولا يحاكي بطاقة فندق أو قطار، ولا يتعامل مع بطاقات الدفع.").font(.footnote).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("الخزنة")
        .sheet(item: $exported) { package in BackupExportSheet(package: package) }
        .sheet(item: $restore) { package in BackupRestoreSheet(package: package) }
        .sheet(item: $wallet) { package in WalletSheet(controller: package.controller) }
        .fileImporter(isPresented: $importing, allowedContentTypes: importingWallet ? [UTType("com.apple.pkpass") ?? .data] : [.tapVaultBackup, .data], allowsMultipleSelection: false) { result in
            do {
                let urls = try result.get(); guard let url = urls.first else { return }
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= BackupCodec.maximumBytes else { throw CardError.tooLarge }
                let data = try Data(contentsOf: url)
                guard data.count <= BackupCodec.maximumBytes else { throw CardError.tooLarge }
                if importingWallet {
                    guard url.pathExtension.lowercased() == "pkpass", PKAddPassesViewController.canAddPasses() else { throw CardError.invalidData }
                    let pass = try PKPass(data: data)
                    guard let controller = PKAddPassesViewController(pass: pass) else { throw CardError.invalidData }
                    wallet = WalletPackage(controller: controller)
                } else { restore = RestorePackage(data: data) }
            } catch { alertText = "تعذر فتح الملف. " + error.localizedDescription }
        }
        .alert("قُرب", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) { Button("حسنًا", role: .cancel) {} } message: { Text(alertText ?? "") }
    }
    private func createBackup() {
        do { let result = try BackupCodec.seal(store.cards); exported = BackupPackage(data: result.data, recoveryKey: result.recoveryKey) }
        catch { alertText = error.localizedDescription }
    }
}

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

struct WalletSheet: UIViewControllerRepresentable {
    let controller: PKAddPassesViewController
    func makeUIViewController(context: Context) -> PKAddPassesViewController { controller }
    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}
}
