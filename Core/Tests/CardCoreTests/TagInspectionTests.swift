import XCTest
@testable import CardCore

final class TagInspectionTests: XCTestCase {
    func testUltralightEV1VariantsAndMemoryDistinction() throws {
        for subtype: UInt8 in [1, 2] {
            let small = try XCTUnwrap(UltralightVersion.parse(Data([0, 4, 3, subtype, 1, 0, 0x0B, 3])))
            XCTAssertEqual(small.userBytes, 48)
            XCTAssertEqual(small.totalBytes, 80)
            let large = try XCTUnwrap(UltralightVersion.parse(Data([0, 4, 3, subtype, 1, 0, 0x0E, 3])))
            XCTAssertEqual(large.userBytes, 128)
            XCTAssertEqual(large.totalBytes, 164)
        }
    }
    func testUnknownOrTruncatedVersionDoesNotInventChipModel() {
        let valid: [UInt8] = [0, 4, 3, 1, 1, 0, 0x0B, 3]
        for length in 0..<8 { XCTAssertNil(UltralightVersion.parse(Data(valid.prefix(length)))) }
        for index in [0, 1, 2, 3, 4, 5, 6, 7] {
            var changed = valid; changed[index] = 0xFF
            XCTAssertNil(UltralightVersion.parse(Data(changed)))
        }
        XCTAssertNil(UltralightVersion.parse(Data(valid + [0])))
    }
    func testNonNDEFCardCanBeSavedAndRestoredWithInspection() throws {
        var card = SavedCard(title: "بطاقة اختبار")
        var inspection = TagInspection(technology: "ISO 14443", family: "MIFARE", identifier: "04:00:00:00:00:00:00")
        inspection.applyUltralightVersion(Data([0, 4, 3, 1, 1, 0, 0x0B, 3]))
        inspection.ndefStatus = "غير متاح"
        card.inspection = inspection
        try card.validate()
        XCTAssertTrue(card.records.isEmpty)
        XCTAssertFalse(card.canWrite)
        XCTAssertEqual(card.capability, "معلومات شريحة مقروءة")
        let sealed = try BackupCodec.seal([card])
        XCTAssertEqual(try BackupCodec.open(sealed.data, recoveryKey: sealed.recoveryKey), [card])
        XCTAssertTrue(inspection.textReport.contains("48"))
        XCTAssertTrue(inspection.textReport.contains("80"))
    }
    func testExistingCardsWithoutInspectionRemainDecodable() throws {
        let original = SavedCard(title: "بطاقة قديمة", records: [try .text("مرحبًا")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "inspection")
        let decoded = try JSONDecoder().decode(SavedCard.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.inspection)
        XCTAssertTrue(decoded.canWrite)
    }
    func testInspectionLimitsProtectBackupImport() throws {
        var card = SavedCard(title: "test")
        var info = TagInspection(technology: "NFC", family: "test", identifier: "00")
        info.userMemoryBytes = 48; info.totalMemoryBytes = 10; card.inspection = info
        XCTAssertThrowsError(try card.validate())
        info.totalMemoryBytes = 80; info.detail = String(repeating: "x", count: 2049); card.inspection = info
        XCTAssertThrowsError(try card.validate())
    }
}
