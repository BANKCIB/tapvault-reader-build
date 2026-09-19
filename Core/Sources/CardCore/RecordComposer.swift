import Foundation

public enum RecordKind: String, CaseIterable, Identifiable, Sendable {
    case text, url, phone, email, sms, location, contact, customURI, json, bytes
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .text: return "نص"
        case .url: return "رابط موقع"
        case .phone: return "رقم هاتف"
        case .email: return "بريد إلكتروني"
        case .sms: return "رسالة نصية"
        case .location: return "موقع على الخريطة"
        case .contact: return "جهة اتصال"
        case .customURI: return "رابط تطبيق أو نظام"
        case .json: return "بيانات JSON"
        case .bytes: return "بيانات ثنائية"
        }
    }
    public var symbol: String {
        switch self {
        case .text: return "text.alignright"
        case .url: return "link"
        case .phone: return "phone"
        case .email: return "envelope"
        case .sms: return "message"
        case .location: return "map"
        case .contact: return "person.crop.rectangle"
        case .customURI: return "app.connected.to.app.below.fill"
        case .json: return "curlybraces"
        case .bytes: return "number"
        }
    }
}

public struct RecordInputError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

/// Pure builders shared by the composer and validation tests. No NFC hardware access.
public extension TagRecord {
    var encodedByteCount: Int {
        // Header, TYPE_LENGTH, PAYLOAD_LENGTH, optional ID_LENGTH, then fields.
        2 + (payload.count < 256 ? 1 : 4) + (identifier.isEmpty ? 0 : 1) + type.count + identifier.count + payload.count
    }
    static func applicationURI(_ input: String) throws -> Self {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 65535,
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              let components = URLComponents(string: value), let scheme = components.scheme,
              !["javascript", "data", "file", "vbscript"].contains(scheme.lowercased()),
              components.user == nil, components.password == nil,
              value.count > scheme.count + 1 else {
            throw RecordInputError("أدخل رابطًا كاملًا دون مسافات، مثل myapp://item/123.")
        }
        if ["http", "https"].contains(scheme.lowercased()) { return try uri(value) }
        let prefixes: [(String, UInt8)] = [("tel:", 5), ("mailto:", 6)]
        let match = prefixes.first { value.hasPrefix($0.0) }
        let record = Self(tnf: 1, type: Data([0x55]), payload: Data([match?.1 ?? 0]) + Data((match.map { String(value.dropFirst($0.0.count)) } ?? value).utf8))
        try record.validate(); return record
    }
    static func phone(_ input: String) throws -> Self {
        try applicationURI("tel:" + normalizedPhone(input))
    }
    static func email(_ address: String, subject: String = "", body: String = "") throws -> Self {
        let value = try normalizedEmail(address)
        var query: [String] = []
        if !subject.isEmpty { query.append("subject=" + component(subject)) }
        if !body.isEmpty { query.append("body=" + component(body)) }
        return try applicationURI("mailto:" + component(value).replacingOccurrences(of: "%40", with: "@") + (query.isEmpty ? "" : "?" + query.joined(separator: "&")))
    }
    static func sms(_ number: String, body: String) throws -> Self {
        try applicationURI("sms:" + normalizedPhone(number) + (body.isEmpty ? "" : "?body=" + component(body)))
    }
    static func location(latitude: String, longitude: String) throws -> Self {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespacesAndNewlines)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespacesAndNewlines)),
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else {
            throw RecordInputError("أدخل خط عرض بين -90 و90 وخط طول بين -180 و180، باستخدام النقطة للفاصل العشري.")
        }
        return try uri("https://maps.apple.com/?ll=\(lat),\(lon)")
    }
    static func contact(name: String, phone: String, email: String, organization: String = "") throws -> Self {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RecordInputError("أدخل اسم جهة الاتصال.") }
        var lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:" + vcardEscape(name), "N:" + vcardEscape(name) + ";;;;"]
        if !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append("TEL;TYPE=CELL:" + (try normalizedPhone(phone))) }
        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append("EMAIL;TYPE=INTERNET:" + (try normalizedEmail(email))) }
        if !organization.isEmpty { lines.append("ORG:" + vcardEscape(organization)) }
        lines.append("END:VCARD")
        return try mime("text/vcard", data: Data((lines.map(foldVCardLine).joined(separator: "\r\n") + "\r\n").utf8))
    }
    static func json(_ input: String) throws -> Self {
        let data = Data(input.utf8)
        guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else { throw RecordInputError("صيغة JSON غير صحيحة. تحقق من الأقواس وعلامات الاقتباس.") }
        return try mime("application/json", data: data)
    }
    static func binary(mimeType: String, hex: String) throws -> Self {
        let value = hex.filter { !$0.isWhitespace }
        guard !value.isEmpty, value.count % 2 == 0, value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }), value.count <= 131072 else {
            throw RecordInputError("أدخل أزواجًا سداسية عشرية مثل 01 A2 FF، بحد أقصى 65536 بايت.")
        }
        let chars = Array(value); var bytes = Data()
        for index in stride(from: 0, to: chars.count, by: 2) { bytes.append(UInt8(String(chars[index...index + 1]), radix: 16)!) }
        return try mime(mimeType, data: bytes)
    }
    static func mime(_ name: String, data: Data) throws -> Self {
        let type = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isMIMEType(type), !data.isEmpty else { throw RecordInputError("أدخل نوع MIME صالحًا مثل application/json ومحتوى غير فارغ.") }
        let record = Self(tnf: 2, type: Data(type.utf8), payload: data)
        try record.validate(); return record
    }
    var mimeType: String? {
        guard tnf == 2, let name = String(data: type, encoding: .utf8), Self.isMIMEType(name) else { return nil }
        return name
    }
    var contentLabel: String {
        if textValue != nil { return "نص" }
        if uriValue != nil { return "رابط أو إجراء" }
        return mimeType ?? "سجل NDEF"
    }
    private static func isMIMEType(_ type: String) -> Bool {
        let parts = type.split(separator: "/", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$&^_.+-")
        return type.utf8.count <= 255 && parts.count == 2 && parts.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }
    }
    private static func normalizedPhone(_ input: String) throws -> String {
        let value = input.filter { !" ()-".contains($0) }
        let digits = value.hasPrefix("+") ? String(value.dropFirst()) : value
        guard !digits.isEmpty, digits.count <= 20, digits.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw RecordInputError("أدخل رقم هاتف بالأرقام 0–9؛ يمكن أن يبدأ بعلامة +.")
        }
        return value
    }
    private static func normalizedEmail(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+-/=?^_`{|}~@")
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }), value.utf8.count <= 254,
              value.unicodeScalars.allSatisfy(allowed.contains),
              parts[1].utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }) else {
            throw RecordInputError("أدخل عنوان بريد صالحًا مثل name@example.com.")
        }
        return value
    }
    private static func component(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? ""
    }
    private static func vcardEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ";", with: "\\;").replacingOccurrences(of: ",", with: "\\,")
    }
    private static func foldVCardLine(_ value: String) -> String {
        var result = ""; var count = 0
        for scalar in value.unicodeScalars {
            let text = String(scalar); let length = text.utf8.count
            if count + length > 75 { result += "\r\n "; count = 1 }
            result += text; count += length
        }
        return result
    }
}
