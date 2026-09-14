import XCTest
@testable import CardCore

final class TagScanRecoveryTests: XCTestCase {
    func testRediscoveryStaysOnOriginalCardAndTechnology() {
        var recovery = TagScanRecovery()
        XCTAssertTrue(recovery.accepts(technology: "A", identifier: "01"))
        XCTAssertTrue(recovery.retryConnectionLoss())
        XCTAssertFalse(recovery.accepts(technology: "A", identifier: "02"))
        XCTAssertFalse(recovery.accepts(technology: "V", identifier: "01"))
        XCTAssertTrue(recovery.accepts(technology: "A", identifier: "01"))
    }
    func testConnectionRetriesAreBounded() {
        var recovery = TagScanRecovery()
        XCTAssertTrue(recovery.accepts(technology: "A", identifier: "01"))
        XCTAssertTrue(recovery.retryConnectionLoss())
        XCTAssertTrue(recovery.retryConnectionLoss())
        for _ in 0..<5 { XCTAssertFalse(recovery.retryConnectionLoss()) }
        XCTAssertEqual(recovery.retryCount, 2)
    }
    func testRepeatedVersionDisconnectFallsBackAfterFreshDiscovery() {
        var recovery = TagScanRecovery()
        _ = recovery.accepts(technology: "A", identifier: "01")
        XCTAssertTrue(recovery.shouldReadVersion)
        XCTAssertTrue(recovery.retryVersionFailure(connectionLost: true))
        XCTAssertTrue(recovery.shouldReadVersion)
        XCTAssertTrue(recovery.retryVersionFailure(connectionLost: true))
        XCTAssertFalse(recovery.shouldReadVersion)
        XCTAssertFalse(recovery.retryVersionFailure(connectionLost: true))
    }
    func testUnsupportedVersionIsNotRepeated() {
        var recovery = TagScanRecovery()
        _ = recovery.accepts(technology: "A", identifier: "01")
        XCTAssertTrue(recovery.retryVersionFailure(connectionLost: false))
        XCTAssertFalse(recovery.shouldReadVersion)
        XCTAssertTrue(recovery.retryConnectionLoss())
    }
    func testNoAutomaticRecoveryWithoutCardIdentity() {
        var recovery = TagScanRecovery()
        XCTAssertFalse(recovery.retryConnectionLoss())
        _ = recovery.accepts(technology: "A", identifier: "")
        XCTAssertFalse(recovery.retryVersionFailure(connectionLost: true))
        XCTAssertEqual(recovery.retryCount, 0)
    }
    func testDiagnosticsArePreservedAndBounded() throws {
        var report = TagInspection(technology: "A", family: "MIFARE", identifier: "01")
        report.diagnostics = ["تحديد الطراز: انقطع الاتصال"]
        XCTAssertTrue(report.textReport.contains("تحديد الطراز"))
        XCTAssertEqual(try JSONDecoder().decode(TagInspection.self, from: JSONEncoder().encode(report)), report)
        report.diagnostics = Array(repeating: "test", count: 9)
        XCTAssertThrowsError(try report.validate())
        report.diagnostics = [String(repeating: "x", count: 513)]
        XCTAssertThrowsError(try report.validate())
    }
}
