import SwiftUI
import UniformTypeIdentifiers
import PassKit
import CardCore

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
            Section("أمان الخزنة") {
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
            Section {
                DisclosureGroup("الخصوصية وحفظ البيانات") {
                    Label("لا يوجد حساب أو خادم للتطبيق", systemImage: "externaldrive")
                    Label("تشفير البيانات والنسخ باستخدام AES-GCM", systemImage: "lock.doc")
                    Label("مفتاح الجهاز محفوظ في Keychain", systemImage: "key")
                    Label("قفل عند الانتقال إلى الخلفية", systemImage: "app.badge.checkmark")
                    Text("مشاركة سجل نصي أو رمز QR تكشف ذلك السجل لمن ترسله إليه. لا توجد مزامنة سحابية تلقائية. حذف التطبيق قد يفقد البيانات؛ احتفظ بنسخة مشفرة ورمزها.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("عن التطبيق") {
                LabeledContent("الإصدار") {
                    Text(versionDescription).accessibilityIdentifier("app-version-value")
                }.accessibilityElement(children: .contain)
                Text("التطبيق قارئ ومنظم لبيانات NFC القياسية. لا يستخرج مفاتيح البطاقات المحمية، ولا يحاكي بطاقة فندق أو قطار، ولا يتعامل مع بطاقات الدفع.").font(.footnote).foregroundStyle(.secondary)
            }
        }.scrollContentBackground(.hidden).background(Theme.background).navigationTitle("الخزنة")
        .sheet(item: $exported) { package in BackupExportSheet(package: package) }
        .sheet(item: $restore) { package in BackupRestoreSheet(package: package) }
        .sheet(item: $wallet) { package in WalletSheet(controller: package.controller) }
        .fileImporter(isPresented: $importing, allowedContentTypes: importingWallet ? [UTType("com.apple.pkpass") ?? .data] : [.tapVaultBackup, .data], allowsMultipleSelection: false, onCompletion: importFile)
        .alert("قُرب", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) { Button("حسنًا", role: .cancel) {} } message: { Text(alertText ?? "") }
    }
    private var versionDescription: String {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
        return "\(version) (\(buildNumber))"
    }

    private func importFile(_ result: Result<[URL], Error>) {
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

    private func createBackup() {
        do { let result = try BackupCodec.seal(store.cards); exported = BackupPackage(data: result.data, recoveryKey: result.recoveryKey) }
        catch { alertText = error.localizedDescription }
    }
}
