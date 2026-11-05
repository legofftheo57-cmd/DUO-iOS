import XCTest

final class DUOUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["-duo-ui-test", UUID().uuidString]; app.launch()
    }
    func testAllTabsAndSettings() {
        for title in ["Accueil", "Tâches", "Courses", "Planning"] {
            app.tabBars.buttons[title].tap(); XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
        }
        app.buttons["Réglages"].tap(); XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 3)); app.buttons["Terminé"].tap()
    }
    func testAddFoodAndPersistAfterRelaunch() {
        app.tabBars.buttons["Accueil"].tap(); app.buttons["openKitchen"].tap(); app.buttons["addFood"].tap()
        let field = app.textFields["itemName"]; XCTAssertTrue(field.waitForExistence(timeout: 3)); field.tap(); field.typeText("Citron test")
        app.buttons["saveItem"].tap(); XCTAssertTrue(app.staticTexts["Citron test"].waitForExistence(timeout: 3))
        app.terminate(); app.launch(); app.tabBars.buttons["Accueil"].tap(); app.buttons["openKitchen"].tap(); XCTAssertTrue(app.staticTexts["Citron test"].waitForExistence(timeout: 3))
    }
    func testCancelFoodDoesNotCreateIt() {
        app.tabBars.buttons["Accueil"].tap(); app.buttons["openKitchen"].tap(); app.buttons["addFood"].tap(); app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Annulation test"); app.buttons["Fermer"].tap(); XCTAssertFalse(app.staticTexts["Annulation test"].exists)
    }
    func testAccessibilityAudit() throws {
        for title in ["Accueil", "Tâches", "Courses", "Planning"] { app.tabBars.buttons[title].tap(); try app.performAccessibilityAudit() }
    }
}
