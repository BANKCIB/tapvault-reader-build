import XCTest

final class TapVaultUITests: XCTestCase {
    @MainActor
    func testLibraryNavigationAndEditing() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["scan-tag"].waitForExistence(timeout: 10))
        capture("01-library-light")
        app.buttons["add-card"].tap()
        app.buttons["نص أو رابط جديد"].tap()
        let title = app.textFields["card-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Demo note")
        let content = app.textViews.firstMatch
        if content.exists { content.tap(); content.typeText("Hello NFC") }
        else { let field = app.textFields["المحتوى"]; field.tap(); field.typeText("Hello NFC") }
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
        app.tabBars.buttons["الخزنة"].tap()
        XCTAssertTrue(app.buttons["create-backup"].waitForExistence(timeout: 5)); capture("04-vault")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
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
