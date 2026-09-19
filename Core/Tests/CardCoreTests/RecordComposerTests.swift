import XCTest
@testable import CardCore

final class RecordComposerTests: XCTestCase {
    func testURLCompressionPreservesDestinationAndSavesSpace() throws {
        for (input, prefix) in [("https://www.example.com/مرحبا", 2), ("http://www.example.com", 1), ("https://example.com", 4), ("http://example.com", 3)] {
            let record = try TagRecord.uri(input)
            XCTAssertEqual(record.uriValue, input)
            XCTAssertEqual(record.payload.first, UInt8(prefix))
            XCTAssertLessThan(record.payload.count, input.utf8.count)
        }
    }
    func testPhoneAndSMSRoundTrip() throws {
        XCTAssertEqual(try TagRecord.phone("+966 (50) 123-4567").uriValue, "tel:+966501234567")
        let sms = try XCTUnwrap(TagRecord.sms("+123", body: "مرحبا &?=#").uriValue)
        let components = try XCTUnwrap(URLComponents(string: sms))
        XCTAssertEqual(components.queryItems?.first?.value, "مرحبا &?=#")
        XCTAssertEqual(components.queryItems?.count, 1)
        for invalid in ["", "+", "12&body=oops", "123\r\n", "１２３"] { XCTAssertThrowsError(try TagRecord.phone(invalid)) }
    }
    func testEmailEscapesHeaderDelimitersAndUnicode() throws {
        let record = try TagRecord.email("user+tag@example.com", subject: "مرحبا &bcc=other", body: "line1\nline2?")
        let url = try XCTUnwrap(URLComponents(string: XCTUnwrap(record.uriValue)))
        XCTAssertEqual(url.path, "user+tag@example.com")
        XCTAssertEqual(url.queryItems?.map(\.name), ["subject", "body"])
        XCTAssertEqual(url.queryItems?.first?.value, "مرحبا &bcc=other")
        for invalid in ["bad", "a@@example.com", "a@example.com?bcc=x", "a\nb@example.com"] { XCTAssertThrowsError(try TagRecord.email(invalid)) }
    }
    func testCoordinateBoundariesAndInvalidNumbers() throws {
        XCTAssertEqual(try TagRecord.location(latitude: "-90", longitude: "180").uriValue, "https://maps.apple.com/?ll=-90.0,180.0")
        for pair in [("91", "0"), ("0", "181"), ("nan", "0"), ("inf", "1"), ("", "1")] {
            XCTAssertThrowsError(try TagRecord.location(latitude: pair.0, longitude: pair.1))
        }
    }
    func testContactEscapingAndUnicodeOctetFolding() throws {
        let name = String(repeating: "محمد", count: 30) + ";,\\\nEND:VCARD"
        let record = try TagRecord.contact(name: name, phone: "+123", email: "a@example.com", organization: "A,B;C")
        XCTAssertEqual(record.mimeType, "text/vcard")
        let text = try XCTUnwrap(String(data: record.payload, encoding: .utf8))
        XCTAssertTrue(text.hasSuffix("END:VCARD\r\n"))
        for line in text.components(separatedBy: "\r\n") { XCTAssertLessThanOrEqual(line.utf8.count, 75) }
        let unfolded = text.replacingOccurrences(of: "\r\n ", with: "")
        XCTAssertTrue(unfolded.contains("\\;\\,\\\\\\nEND:VCARD"))
        XCTAssertEqual(text.components(separatedBy: "\r\nEND:VCARD").count, 2)
        XCTAssertTrue(record.isWritableContent)
    }
    func testJSONValidationPreservesBytes() throws {
        let source = "{\"name\":\"عربي\",\"id\":1}"
        let record = try TagRecord.json(source)
        XCTAssertEqual(record.payload, Data(source.utf8)); XCTAssertEqual(record.mimeType, "application/json")
        XCTAssertThrowsError(try TagRecord.json("{invalid}"))
    }
    func testBinaryValidationAndExactBytes() throws {
        let record = try TagRecord.binary(mimeType: "application/octet-stream", hex: "00 ff\nA2 10")
        XCTAssertEqual(record.payload, Data([0, 255, 162, 16])); XCTAssertTrue(record.isWritableContent)
        for hex in ["A", "0xFF", "ZZ", ""] { XCTAssertThrowsError(try TagRecord.binary(mimeType: "application/octet-stream", hex: hex)) }
        for mime in ["bad", "a/", "/b", "a/b\nX:y", "text/plain;charset=utf-8"] { XCTAssertThrowsError(try TagRecord.mime(mime, data: Data([1]))) }
    }
    func testCustomURIsDoNotAllowExecutableSchemesOrCredentials() throws {
        XCTAssertEqual(try TagRecord.applicationURI("inventory://item/123").uriValue, "inventory://item/123")
        for value in ["javascript:alert(1)", "data:text/html,x", "file:///a", "https://u:p@example.com", "myapp:", "myapp://a b"] { XCTAssertThrowsError(try TagRecord.applicationURI(value)) }
    }
    func testEncodedSizeIncludesLongPayloadAndIdentifiers() {
        XCTAssertEqual(TagRecord(tnf: 2, type: Data([1]), payload: Data(count: 255)).encodedByteCount, 259)
        XCTAssertEqual(TagRecord(tnf: 2, type: Data([1]), payload: Data(count: 256)).encodedByteCount, 263)
        XCTAssertEqual(TagRecord(tnf: 2, type: Data([1]), identifier: Data([1, 2]), payload: Data(count: 256)).encodedByteCount, 266)
    }
    func testAllTemplatesSurviveEncryptedBackupAndRemainWritable() throws {
        let records: [TagRecord] = try [.text("عربي"), .uri("https://example.com"), .phone("123"), .email("a@example.com"), .sms("123", body: "Hello"), .location(latitude: "0", longitude: "0"), .contact(name: "Test", phone: "", email: ""), .applicationURI("inventory://1"), .json("{}"), .binary(mimeType: "application/octet-stream", hex: "00FF")]
        let card = SavedCard(title: "Writer", records: records)
        try card.validate(); XCTAssertTrue(card.canWrite)
        XCTAssertEqual(card.encodedByteCount, records.reduce(0) { $0 + $1.encodedByteCount })
        let backup = try BackupCodec.seal([card])
        XCTAssertEqual(try BackupCodec.open(backup.data, recoveryKey: backup.recoveryKey), [card])
    }
    func testMalformedImportedMIMEIsNotWritable() {
        XCTAssertFalse(TagRecord(tnf: 2, type: Data("invalid".utf8), payload: Data([1])).isWritableContent)
        XCTAssertFalse(TagRecord(tnf: 2, type: Data("text/plain".utf8), payload: Data()).isWritableContent)
    }
}
