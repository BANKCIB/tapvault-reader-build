import XCTest
import CryptoKit
@testable import CardCore

final class CardCoreTests: XCTestCase {
    func testArabicTextRoundTrip() throws {
        let record = try TagRecord.text("مرحبًا بالعالم")
        XCTAssertEqual(record.textValue, "مرحبًا بالعالم"); XCTAssertTrue(record.isWritableContent)
    }
    func testURLSchemesAndCredentialsRejected() {
        for value in ["javascript:alert(1)", "file:///private/key", "https://u:p@example.com", "not a url", "https://example.com/a b"] {
            XCTAssertThrowsError(try TagRecord.uri(value))
        }
    }
    func testCompressedNDEFURI() {
        let record = TagRecord(tnf: 1, type: Data([0x55]), payload: Data([4]) + Data("example.com".utf8))
        XCTAssertEqual(record.uriValue, "https://example.com"); XCTAssertTrue(record.isWritableContent)
    }
    func testMalformedTextCannotBeWritten() {
        let record = TagRecord(tnf: 1, type: Data([0x54]), payload: Data([63, 0xff]))
        XCTAssertNil(record.textValue); XCTAssertFalse(record.isWritableContent)
    }
    func testUnknownRecordsPreservedButNotWritable() {
        let record = TagRecord(tnf: 2, type: Data("application/octet-stream".utf8), payload: Data([1, 2, 3]))
        XCTAssertFalse(SavedCard(title: "raw", records: [record]).canWrite)
    }
    func testReferenceCardIsNotAKey() { XCTAssertFalse(SavedCard(title: "Hotel", category: .hotel).canWrite) }
    func testBackupRoundTripAndRandomizedEncryption() throws {
        let cards = [SavedCard(title: "خاص", records: [try .text("بيانات خاصة")])]
        let first = try BackupCodec.seal(cards); let second = try BackupCodec.seal(cards)
        XCTAssertEqual(try BackupCodec.open(first.data, recoveryKey: first.recoveryKey), cards)
        XCTAssertNotEqual(first.data, second.data); XCTAssertNotEqual(first.recoveryKey, second.recoveryKey)
        XCTAssertFalse(String(decoding: first.data, as: UTF8.self).contains("بيانات خاصة"))
    }
    func testWrongKeyRejected() throws {
        let sealed = try BackupCodec.seal([SavedCard(title: "Test")])
        let wrong = try BackupCodec.seal([]).recoveryKey
        XCTAssertThrowsError(try BackupCodec.open(sealed.data, recoveryKey: wrong))
    }
    func testTamperedBackupRejected() throws {
        let backup = try BackupCodec.seal([SavedCard(title: "Test")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: backup.data) as? [String: Any])
        var bytes = try XCTUnwrap(Data(base64Encoded: object["sealed"] as! String)); bytes[bytes.count - 1] ^= 1
        object["sealed"] = bytes.base64EncodedString()
        XCTAssertThrowsError(try BackupCodec.open(JSONSerialization.data(withJSONObject: object), recoveryKey: backup.recoveryKey))
    }
    func testUnknownBackupVersionRejected() throws {
        let backup = try BackupCodec.seal([])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: backup.data) as? [String: Any]); object["version"] = 99
        XCTAssertThrowsError(try BackupCodec.open(JSONSerialization.data(withJSONObject: object), recoveryKey: backup.recoveryKey))
    }
    func testMergeKeepsExistingAndDeduplicatesContent() throws {
        let original = SavedCard(title: "one", records: [try .text("hello")])
        let sameContent = SavedCard(title: "two", records: original.records)
        let reference = SavedCard(title: "reference")
        XCTAssertEqual(try CardCollection.merging([sameContent, reference], into: [original]), [original, reference])
    }
    func testLimitsAndDuplicateIDs() throws {
        let card = SavedCard(title: "one")
        XCTAssertThrowsError(try CardCollection.validate([card, card]))
        XCTAssertThrowsError(try TagRecord.text(String(repeating: "a", count: 65537)))
        XCTAssertThrowsError(try SavedCard(title: " ").validate())
        XCTAssertThrowsError(try BackupCodec.open(Data(count: BackupCodec.maximumBytes + 1), recoveryKey: ""))
    }
    func testCollectionSizeCannotExceedReopenLimit() throws {
        let cards = try (0..<40).map { index in SavedCard(title: "\(index)", records: [try .text(String(repeating: "a", count: 60000))]) }
        XCTAssertThrowsError(try CardCollection.validate(cards))
    }
}
