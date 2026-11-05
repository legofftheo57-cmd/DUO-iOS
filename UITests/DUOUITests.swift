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
    func testCreatePlanningEventAndEditTitle() {
        app.tabBars.buttons["Planning"].tap()
        app.buttons["Ajouter un événement"].tap()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Rendez-vous DUO test")
        app.buttons["saveItem"].tap()
        let event = app.staticTexts["Rendez-vous DUO test"]
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        event.tap()
        let edited = app.textFields["itemName"]
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
        edited.tap()
        edited.press(forDuration: 1)
        let selectAll = app.menuItems["Tout sélectionner"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
            edited.typeText("Rendez-vous DUO modifié")
        } else {
            edited.typeText(" modifié")
        }
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "modifié")).firstMatch.waitForExistence(timeout: 5))
    }

    func testAssistantOpensAndCloses() {
        app.tabBars.buttons["Accueil"].tap()
        app.buttons["Parler à Joe"].tap()
        XCTAssertTrue(app.navigationBars["Joe"].waitForExistence(timeout: 5))
        app.buttons["Fermer"].tap()
        XCTAssertTrue(app.navigationBars["Accueil"].waitForExistence(timeout: 5))
    }

    func testShoppingItemPersistsAfterRelaunch() {
        app.tabBars.buttons["Accueil"].tap()
        app.buttons["quickAddShopping"].tap()
        let name = app.textFields["itemName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Pâtes DUO sauvegarde")
        app.buttons["saveItem"].tap()
        app.tabBars.buttons["Courses"].tap()
        XCTAssertTrue(app.staticTexts["Pâtes DUO sauvegarde"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Courses"].tap()
        XCTAssertTrue(app.staticTexts["Pâtes DUO sauvegarde"].waitForExistence(timeout: 5))
    }

    func testCoupleIdeasTabAndCompletion() {
        app.tabBars.buttons["Nous"].tap()
        XCTAssertTrue(app.navigationBars["Nous"].waitForExistence(timeout: 5))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "coupleIdeaToggle"))
        XCTAssertEqual(buttons.count, 3)
        let first = buttons.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(first.label.contains("Fait ensemble"))
        first.tap()
        XCTAssertTrue(first.label.contains("On l'a fait"))
    }

    func testCoupleIdeasFromHome() {
        app.tabBars.buttons["Accueil"].tap()
        let entry = app.buttons["openCoupleIdeas"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.navigationBars["Nous deux"].waitForExistence(timeout: 5))
    }

}
