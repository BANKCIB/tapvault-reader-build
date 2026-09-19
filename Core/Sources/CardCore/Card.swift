import Foundation
import CryptoKit

public enum CardError: LocalizedError {
    case invalidData, invalidURL, unsupportedRecord, tooLarge, invalidKey, unsupportedBackup
    public var errorDescription: String? {
        switch self {
        case .invalidData: return "البيانات غير صالحة. تحقق من الملف وحاول مجددًا."
        case .invalidURL: return "أدخل رابطًا كاملًا يبدأ بـ https:// أو http://."
        case .unsupportedRecord: return "نوع السجل غير مدعوم للكتابة. استخدم نصًا أو رابطًا أو سجل MIME صالحًا."
        case .tooLarge: return "تجاوزت البيانات الحجم المسموح. قلل المحتوى وحاول مجددًا."
        case .invalidKey: return "رمز الاستعادة غير صالح. استخدم الرمز الكامل المرافق للنسخة."
        case .unsupportedBackup: return "إصدار النسخة الاحتياطية غير مدعوم."
        }
    }
}

public enum CardCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal, hotel, transit, work
    public var id: String { rawValue }
    public var title: String {
        switch self { case .personal: return "شخصي"; case .hotel: return "فندق"; case .transit: return "تنقل"; case .work: return "عمل" }
    }
    public var symbol: String {
        switch self { case .personal: return "tag"; case .hotel: return "building.2"; case .transit: return "tram"; case .work: return "briefcase" }
    }
}

public struct TagRecord: Codable, Hashable, Sendable {
    public var tnf: UInt8
    public var type: Data
    public var identifier: Data
    public var payload: Data
    public init(tnf: UInt8, type: Data, identifier: Data = Data(), payload: Data) {
        self.tnf = tnf; self.type = type; self.identifier = identifier; self.payload = payload
    }
    public static func text(_ text: String) throws -> Self {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CardError.invalidData }
        let record = Self(tnf: 1, type: Data([0x54]), payload: Data([2, 0x61, 0x72]) + Data(text.utf8))
        try record.validate(); return record
    }
    public static func uri(_ string: String) throws -> Self {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, !value.contains(where: { $0.isWhitespace }), url.user == nil, url.password == nil else { throw CardError.invalidURL }
        let prefixes: [(String, UInt8)] = [("https://www.", 2), ("http://www.", 1), ("https://", 4), ("http://", 3)]
        let match = prefixes.first { value.hasPrefix($0.0) }
        let record = Self(tnf: 1, type: Data([0x55]), payload: Data([match?.1 ?? 0]) + Data((match.map { String(value.dropFirst($0.0.count)) } ?? value).utf8))
        try record.validate(); return record
    }
    public var textValue: String? {
        guard tnf == 1, type == Data([0x54]), let status = payload.first, status & 0x40 == 0 else { return nil }
        let start = 1 + Int(status & 0x3f)
        guard payload.count >= start else { return nil }
        let bytes = payload.dropFirst(start)
        return String(data: Data(bytes), encoding: status & 0x80 == 0 ? .utf8 : .utf16)
    }
    public var uriValue: String? {
        guard tnf == 1, type == Data([0x55]), let prefix = payload.first else { return nil }
        let prefixes = ["", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:"]
        guard Int(prefix) < prefixes.count, let suffix = String(data: payload.dropFirst(), encoding: .utf8) else { return nil }
        return prefixes[Int(prefix)] + suffix
    }
    public var displayValue: String {
        if let value = textValue ?? uriValue { return value }
        if let mimeType {
            if mimeType.hasPrefix("text/") || mimeType == "application/json", let text = String(data: payload, encoding: .utf8) { return text }
            return "\(mimeType) · \(payload.count) بايت"
        }
        return "بيانات NDEF خام · \(payload.count) بايت"
    }
    public var isWritableContent: Bool {
        guard (try? validate()) != nil else { return false }
        if let text = textValue { return !text.isEmpty }
        if let uri = uriValue { return (try? Self.applicationURI(uri)) != nil }
        if mimeType != nil { return !payload.isEmpty }
        return false
    }
    public func validate() throws {
        guard tnf <= 6, type.count <= 255, identifier.count <= 255 else { throw CardError.invalidData }
        guard payload.count <= 65536 else { throw CardError.tooLarge }
    }
}

public struct SavedCard: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var category: CardCategory
    public var notes: String
    public var issuerURL: String
    public var records: [TagRecord]
    public var createdAt: Date
    public var updatedAt: Date
    public var favorite: Bool
    public var source: String
    public var capacity: Int?
    public var sourceWritable: Bool?
    public var expiresAt: Date?
    public var inspection: TagInspection?
    public init(id: UUID = UUID(), title: String, category: CardCategory = .personal, notes: String = "", issuerURL: String = "", records: [TagRecord] = [], source: String = "يدوي", capacity: Int? = nil, sourceWritable: Bool? = nil, expiresAt: Date? = nil) {
        self.id = id; self.title = title; self.category = category; self.notes = notes; self.issuerURL = issuerURL
        self.records = records; self.source = source; self.capacity = capacity; self.sourceWritable = sourceWritable; self.expiresAt = expiresAt
        self.createdAt = Date(); self.updatedAt = Date(); self.favorite = false
    }
    public var canWrite: Bool { !records.isEmpty && records.allSatisfy(\.isWritableContent) }
    public var encodedByteCount: Int { records.reduce(0) { $0 + $1.encodedByteCount } }
    public var isExpired: Bool { expiresAt.map { $0 < Date() } ?? false }
    public var capability: String { records.isEmpty ? (inspection == nil ? "مرجع محفوظ" : "معلومات شريحة مقروءة") : canWrite ? "بيانات قابلة للكتابة" : "بيانات للفحص" }
    public var fingerprint: String? {
        guard !records.isEmpty else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(records) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public func validate() throws {
        try inspection?.validate()
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 120,
              notes.count <= 10000, issuerURL.count <= 2048, source.count <= 120, records.count <= 32 else { throw CardError.invalidData }
        if !issuerURL.isEmpty { _ = try TagRecord.uri(issuerURL) }
        for record in records { try record.validate() }
        guard records.reduce(0, { $0 + $1.payload.count }) <= 65536 else { throw CardError.tooLarge }
        if let capacity, capacity < 0 { throw CardError.invalidData }
    }
}

public enum CardCollection {
    public static func validate(_ cards: [SavedCard]) throws {
        guard cards.count <= 1000, Set(cards.map(\.id)).count == cards.count else { throw CardError.invalidData }
        for card in cards { try card.validate() }
        guard try JSONEncoder().encode(cards).count <= 2 * 1024 * 1024 else { throw CardError.tooLarge }
    }
    public static func merging(_ incoming: [SavedCard], into current: [SavedCard]) throws -> [SavedCard] {
        try validate(incoming); try validate(current)
        var result = current
        var ids = Set(current.map(\.id)); var prints = Set(current.compactMap(\.fingerprint))
        for card in incoming {
            if ids.contains(card.id) || card.fingerprint.map({ prints.contains($0) }) == true { continue }
            result.append(card); ids.insert(card.id)
            if let fingerprint = card.fingerprint { prints.insert(fingerprint) }
        }
        try validate(result); return result
    }
}
