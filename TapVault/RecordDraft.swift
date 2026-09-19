import Foundation
import CardCore

struct RecordDraft: Identifiable {
    let id: UUID
    var kind: RecordKind = .text
    var value = ""
    var secondary = ""
    var body = ""
    var extra = ""
    // Preserve the original encoding while its editable fields are unchanged.
    var preserved: TagRecord?
    init(id: UUID = UUID()) { self.id = id }
    init(record: TagRecord) {
        id = UUID(); preserved = record
        if let text = record.textValue { kind = .text; value = text }
        else if let uri = record.uriValue { kind = (try? TagRecord.uri(uri)) == nil ? .customURI : .url; value = uri }
        else if record.mimeType == "application/json", let json = String(data: record.payload, encoding: .utf8) { kind = .json; value = json }
        else { kind = .bytes; value = record.payload.map { String(format: "%02X", $0) }.joined(separator: " "); secondary = record.mimeType ?? "application/octet-stream" }
    }
    func hasSameFields(as other: RecordDraft) -> Bool {
        kind == other.kind && value == other.value && secondary == other.secondary && body == other.body && extra == other.extra
    }
    func makeRecord() throws -> TagRecord {
        if let preserved { return preserved }
        switch kind {
        case .text: return try .text(value)
        case .url: return try .uri(value)
        case .phone: return try .phone(value)
        case .email: return try .email(value, subject: secondary, body: body)
        case .sms: return try .sms(value, body: body)
        case .location: return try .location(latitude: value, longitude: secondary)
        case .contact: return try .contact(name: value, phone: secondary, email: body, organization: extra)
        case .customURI: return try .applicationURI(value)
        case .json: return try .json(value)
        case .bytes: return try .binary(mimeType: secondary, hex: value)
        }
    }
}
