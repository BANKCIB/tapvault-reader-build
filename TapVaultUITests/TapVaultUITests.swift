import XCTest
import CoreNFC
import CardCore

final class TapVaultUITests: XCTestCase {
    func testDisplayedSizeMatchesAppleNDEFEncoder() throws {
        let records: [TagRecord] = try [.uri("https://example.com"), .text("مرحبا"), .mime("application/octet-stream", data: Data(count: 255)), .mime("application/octet-stream", data: Data(count: 256)), TagRecord(tnf: 2, type: Data("text/plain".utf8), identifier: Data([1, 2]), payload: Data([65]))]
        let payloads = records.map { NFCNDEFPayload(format: NFCTypeNameFormat(rawValue: $0.tnf)!, type: $0.type, identifier: $0.identifier, payload: $0.payload) }
        XCTAssertEqual(NFCNDEFMessage(records: payloads).length, records.reduce(0) { $0 + $1.encodedByteCount })
    }
    @MainActor
    func testLibraryNavigationAndEditing() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["scan-tag"].waitForExistence(timeout: 10))
        capture("01-library-light")
        app.buttons["add-card"].tap()
        app.buttons["تجهيز وسم جديد"].tap()
        let title = app.textFields["card-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Demo note")
        app.buttons["add-record"].tap()
        let field = app.textFields["النص"].exists ? app.textFields["النص"] : app.textViews["النص"]; XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Hello NFC")
        app.buttons["confirm-record"].tap()
        app.buttons["save-card"].tap()
        XCTAssertTrue(app.staticTexts["Demo note"].waitForExistence(timeout: 5))
        app.staticTexts["Demo note"].tap()
        XCTAssertTrue(app.staticTexts["Hello NFC"].waitForExistence(timeout: 5))
        capture("02-card-details")
    }
    @MainActor
    func testToolsAndVault() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        app.tabBars.buttons["الأدوات"].tap(); capture("03-tools")
        XCTAssertTrue(app.buttons["open-writer"].exists)
        app.buttons["قراءة متقدمة"].tap()
        XCTAssertTrue(app.buttons["قراءة NDEF مباشرة"].exists)
        app.tabBars.buttons["الخزنة"].tap()
        XCTAssertTrue(app.buttons["create-backup"].waitForExistence(timeout: 5)); capture("04-vault")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["1.2.1 (6)"].exists)
    }
    private func capture(_ name: String) {
        // XCTest can return from a tap before the sheet transition finishes.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testSwitchingRecordTypeKeepsDraft() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        app.buttons["add-card"].tap(); app.buttons["تجهيز وسم جديد"].tap()
        app.buttons["add-record"].tap()
        let text = app.textFields["النص"].exists ? app.textFields["النص"] : app.textViews["النص"]
        text.tap(); text.typeText("Keep my draft")
        app.buttons["record-kind"].tap(); app.buttons["رابط موقع"].tap()
        let url = app.textFields["الرابط"]; url.tap(); url.typeText("https://example.com")
        app.buttons["record-kind"].tap(); app.buttons["نص"].tap()
        XCTAssertEqual(text.value as? String, "Keep my draft")
        app.buttons["record-kind"].tap(); app.buttons["رابط موقع"].tap()
        XCTAssertEqual(url.value as? String, "https://example.com")
        app.buttons["confirm-record"].tap()
        XCTAssertTrue(app.staticTexts["https://example.com"].exists)
    }

    @MainActor
    func testWriterValidationMultipleRecordsAndEditRoundTrip() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        app.tabBars.buttons["الأدوات"].tap()
        let writer = app.buttons["open-writer"]
        if !writer.isHittable { app.swipeUp() }; writer.tap()
        XCTAssertFalse(app.buttons["save-card"].isEnabled)
        let title = app.textFields["card-title"]; title.tap(); title.typeText("Multi record")
        app.buttons["add-record"].tap()
        app.buttons["record-kind"].tap(); app.buttons["رابط موقع"].tap()
        let url = app.textFields["الرابط"]; url.tap(); url.typeText("invalid")
        app.buttons["confirm-record"].tap()
        XCTAssertTrue(app.buttons["confirm-record"].exists)
        url.tap(); url.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "https://example.com")
        capture("06-url-editor")
        app.buttons["confirm-record"].tap()
        app.buttons["add-record"].tap()
        app.buttons["record-kind"].tap(); app.buttons["بيانات JSON"].tap()
        let json = app.textFields["بيانات JSON"].exists ? app.textFields["بيانات JSON"] : app.textViews["بيانات JSON"]; json.tap(); json.typeText("{\"id\":123}")
        app.buttons["confirm-record"].tap()
        capture("07-multiple-records")
        app.buttons["save-card"].tap()
        app.tabBars.buttons["مكتبتي"].tap()
        let card = app.staticTexts["Multi record"]; XCTAssertTrue(card.waitForExistence(timeout: 5)); if !card.isHittable { app.swipeUp() }; card.tap()
        XCTAssertTrue(app.staticTexts["https://example.com"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["{\"id\":123}"].exists)
        let edit = app.buttons["edit-records"]; if !edit.isHittable { app.swipeUp() }; edit.tap()
        app.buttons["save-card"].tap()
        XCTAssertTrue(app.staticTexts["{\"id\":123}"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWriterDarkModeAndContactPreview() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--uitesting-dark"]; app.launch()
        app.buttons["add-card"].tap(); app.buttons["تجهيز وسم جديد"].tap()
        capture("08-writer-dark-empty")
        app.buttons["add-record"].tap()
        app.buttons["record-kind"].tap(); app.buttons["جهة اتصال"].tap()
        let name = app.textFields["الاسم"]; name.tap(); name.typeText("Demo Contact")
        capture("09-contact-editor-dark")
        app.buttons["confirm-record"].tap()
        XCTAssertTrue(app.staticTexts["جهة اتصال"].exists)
    }

    @MainActor
    func testInspectionWithoutNDEFAndEditPreservesMetadata() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--inspection-fixture"]; app.launch()
        let sample = app.staticTexts["شريحة اختبار بلا NDEF"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        if !sample.isHittable { app.swipeUp() }
        sample.tap()
        XCTAssertTrue(app.staticTexts["تم التعرف على الشريحة"].waitForExistence(timeout: 5))
        capture("05-non-ndef-chip-details")
        app.buttons["تعديل"].tap()
        XCTAssertTrue(app.staticTexts["نوع الشريحة"].waitForExistence(timeout: 5))
        app.buttons["save-card"].tap()
        XCTAssertTrue(app.staticTexts["تم التعرف على الشريحة"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["كتابة على وسم آخر"].exists)
    }
}
