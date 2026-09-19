import Foundation
import SwiftUI
import CryptoKit
import Security
import CardCore

@MainActor
final class VaultStore: ObservableObject {
    @Published private(set) var cards: [SavedCard] = []
    @Published private(set) var isReady = false
    @Published var errorMessage: String?
    private var isPreview = false
    private var storageName: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-persistence") { return "TapVaultUITests" }
        #endif
        return "TapVault"
    }
    private var service: String {
        storageName == "TapVault" ? "com.m7madv.tapvault.local-key.v1" : "com.m7madv.tapvault.uitests"
    }
    private var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(storageName, isDirectory: true).appendingPathComponent("cards.sealed")
    }
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            isPreview = true; isReady = true
            var tag = SavedCard(title: "بطاقة التواصل", notes: "رابط صفحتي الشخصية؛ جاهز للكتابة على وسم فارغ.", records: [(try? .uri("https://example.com"))].compactMap { $0 })
            tag.favorite = true
            cards = [tag, SavedCard(title: "إقامتي القادمة", category: .hotel, notes: "معلومات الحجز فقط. مفتاح الغرفة يصدر من الفندق.", issuerURL: "https://example.com"), SavedCard(title: "رحلات المدينة", category: .transit, notes: "مرجع لبطاقة التنقل؛ ليس تذكرة إلكترونية.")]
            if ProcessInfo.processInfo.arguments.contains("--inspection-fixture") {
                var sample = SavedCard(title: "شريحة اختبار بلا NDEF", source: "بيانات اختبار واجهة")
                var inspection = TagInspection(technology: "ISO 14443 · Type A", family: "MIFARE Ultralight", identifier: "04:00:00:00:00:00:00")
                inspection.applyUltralightVersion(Data([0, 4, 3, 1, 1, 0, 0x0B, 3]))
                inspection.ndefStatus = "غير متاح"
                inspection.detail = "بيانات اختبار للواجهة. لا تتوفر رسالة NDEF؛ تبقى معلومات الشريحة قابلة للعرض والحفظ."
                sample.inspection = inspection; cards.insert(sample, at: 0)
            }
        }
        #endif
    }
    func openLibrary() {
        guard !isReady else { return }
        errorMessage = nil
        do {
            cards = try load()
            isReady = true
        } catch {
            // Keep writes disabled if existing data cannot be read.
            errorMessage = error.localizedDescription
        }
    }
    func save(_ card: SavedCard) throws {
        guard isReady else { throw CardError.invalidData }
        try card.validate()
        var next = cards
        if let index = next.firstIndex(where: { $0.id == card.id }) { next[index] = card }
        else {
            if let fingerprint = card.fingerprint, next.contains(where: { $0.fingerprint == fingerprint }) {
                throw NSError(domain: "TapVault", code: 2, userInfo: [NSLocalizedDescriptionKey: "هذه البيانات محفوظة مسبقًا. افتح البطاقة الموجودة لتعديلها."])
            }
            next.insert(card, at: 0)
        }
        try commit(next)
    }
    func toggleFavorite(_ card: SavedCard) {
        var updated = card; updated.favorite.toggle(); updated.updatedAt = Date()
        do { try save(updated) } catch { errorMessage = error.localizedDescription }
    }
    func delete(_ id: UUID) throws { try commit(cards.filter { $0.id != id }) }
    func merge(_ restored: [SavedCard]) throws -> Int {
        let next = try CardCollection.merging(restored, into: cards)
        let count = next.count - cards.count; try commit(next); return count
    }
    private func commit(_ next: [SavedCard]) throws {
        guard isReady else { throw CardError.invalidData }
        try CardCollection.validate(next)
        if !isPreview {
            let key = try encryptionKey(create: !FileManager.default.fileExists(atPath: fileURL.path))
            let data = try JSONEncoder().encode(next)
            guard let sealed = try AES.GCM.seal(data, using: key).combined else { throw CardError.invalidData }
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var mutableDirectory = directory; try mutableDirectory.setResourceValues(values)
            try sealed.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
        cards = next
    }
    private func load() throws -> [SavedCard] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let key = try encryptionKey(create: false)
        let sealed = try Data(contentsOf: fileURL)
        guard sealed.count <= BackupCodec.maximumBytes else { throw CardError.tooLarge }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
        let loaded = try JSONDecoder().decode([SavedCard].self, from: plain)
        try CardCollection.validate(loaded); return loaded
    }
    private func encryptionKey(create: Bool) throws -> SymmetricKey {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                  kSecAttrService as String: service, kSecAttrAccount as String: "vault"]
        var read = query; read[kSecReturnData as String] = true; read[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(read as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound, create else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "تعذر فتح مفتاح الخزنة. لم تُغيّر بياناتك. حاول بعد فتح قفل الجهاز أو استعد نسخة احتياطية على تثبيت جديد."])
        }
        let key = SymmetricKey(size: .bits256)
        var add = query
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        add[kSecAttrSynchronizable as String] = false
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        return key
    }
}
