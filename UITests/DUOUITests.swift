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
    func testQuickAddTaskAndPersistLocally() {
        app.tabBars.buttons["Accueil"].tap()
        app.buttons["quickAddTask"].tap()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("DUO tâche test")
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.staticTexts["DUO tâche test"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["DUO tâche test"].waitForExistence(timeout: 5))
    }
    func testQuickAddShoppingFromHome() {
        app.tabBars.buttons["Accueil"].tap()
        app.buttons["quickAddShopping"].tap()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Riz test")
        app.buttons["saveItem"].tap()
        app.tabBars.buttons["Courses"].tap()
        XCTAssertTrue(app.staticTexts["Riz test"].waitForExistence(timeout: 5))
    }
    func testUndoCompletedHouseholdTask() {
        app.tabBars.buttons["Tâches"].tap()
        app.buttons["addTask"].tap()
        let title = app.textFields["itemName"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("DUO annulation test")
        app.buttons["saveItem"].tap()
        let finish = app.buttons["Terminer DUO annulation test"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        let history = app.switches["Voir l’historique"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        let undo = app.buttons["Rouvrir DUO annulation test"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        history.tap()
        XCTAssertTrue(app.buttons["Terminer DUO annulation test"].waitForExistence(timeout: 5))
    }
    func testAccessibilityAudit() throws {
        for title in ["Accueil", "Tâches", "Courses", "Planning"] { app.tabBars.buttons[title].tap(); try app.performAccessibilityAudit() }
    }
}
