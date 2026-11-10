import XCTest

final class DUOUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["-duo-ui-test", UUID().uuidString, "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]; app.launch()
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
        let history = app.buttons["Terminées"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        let undo = app.buttons["Rouvrir DUO annulation test"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        app.buttons["À faire"].tap()
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
        let oldValue = edited.value as? String ?? ""
        edited.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + "Rendez-vous DUO modifié")
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
        XCTAssertTrue(app.navigationBars["Nous deux"].waitForExistence(timeout: 5))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "coupleIdeaToggle"))
        XCTAssertEqual(buttons.count, 3)
        let first = buttons.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(first.label.contains("Fait ensemble"))
        let identifier = first.identifier
        app.terminate(); app.launch(); app.tabBars.buttons["Nous"].tap()
        let restored = app.buttons[identifier]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertTrue(restored.label.contains("Fait ensemble"))
        restored.tap()
        XCTAssertTrue(restored.label.contains("On l'a fait"))
    }

    func testCoupleIdeasFromHome() {
        app.tabBars.buttons["Accueil"].tap()
        let entry = app.buttons["openCoupleIdeas"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        reveal(entry)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Nous deux"].waitForExistence(timeout: 5))
    }

}

extension DUOUITests {
    func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Élément inaccessible : \(element)")
    }
    func rename(_ title: String) {
        let field = app.textFields["itemName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + title)
        app.buttons["saveItem"].tap()
    }
    func deleteRow(_ title: String) {
        let row = app.staticTexts[title]; reveal(row); row.swipeLeft()
        let delete = app.buttons["Supprimer"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5)); delete.tap()
        XCTAssertFalse(app.staticTexts[title].exists)
    }
    func testTaskEditDeleteAndEmptyInput() {
        app.tabBars.buttons["Tâches"].tap(); app.buttons["addTask"].tap()
        XCTAssertFalse(app.buttons["saveItem"].isEnabled)
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Tâche initiale")
        app.buttons["saveItem"].tap()
        app.staticTexts["Tâche initiale"].tap(); rename("Tâche modifiée")
        XCTAssertTrue(app.staticTexts["Tâche modifiée"].waitForExistence(timeout: 5))
        deleteRow("Tâche modifiée")
    }
    func testShoppingEditCheckUncheckAndDelete() {
        app.tabBars.buttons["Courses"].tap(); app.buttons["addShopping"].tap()
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Pain test")
        app.buttons["saveItem"].tap(); app.staticTexts["Pain test"].tap(); rename("Pain complet test")
        app.buttons["Cocher Pain complet test"].tap()
        let undo = app.buttons["Remettre Pain complet test à acheter"]; reveal(undo); undo.tap()
        XCTAssertTrue(app.buttons["Cocher Pain complet test"].waitForExistence(timeout: 5))
        deleteRow("Pain complet test")
    }
    func testHabitAndSportCreation() {
        app.tabBars.buttons["Tâches"].tap(); app.buttons["Sport & habitudes"].tap()
        app.buttons["Créer une habitude"].tap()
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Marche test")
        app.buttons["saveItem"].tap(); app.buttons["Fait aujourd’hui"].tap()
        XCTAssertTrue(app.buttons["Annuler aujourd’hui"].waitForExistence(timeout: 5))
        app.buttons["Annuler aujourd’hui"].tap()
        app.buttons["Prévoir une séance"].tap()
        app.textFields["itemName"].tap(); app.textFields["itemName"].typeText("Sport test")
        app.buttons["saveItem"].tap()
        XCTAssertTrue(app.staticTexts["Sport test"].waitForExistence(timeout: 5))
    }
    func testJoeConfirmedShoppingAction() {
        app.buttons["Parler à Joe"].tap()
        let example = app.buttons["Ajoute 2 kg de riz aux courses"]; reveal(example); example.tap()
        app.buttons["Réponse locale gratuite"].tap()
        let confirm = app.buttons["Confirmer"]; reveal(confirm); confirm.tap()
        XCTAssertTrue(app.staticTexts["C’est fait. La modification est enregistrée sur cet iPhone."].waitForExistence(timeout: 5))
        app.buttons["Fermer"].tap(); app.tabBars.buttons["Courses"].tap()
        XCTAssertTrue(app.staticTexts["riz"].waitForExistence(timeout: 5))
    }
    func testMealPlanCreatesMealsAndShopping() {
        app.buttons["openKitchen"].tap()
        let compose = app.buttons["Composer plusieurs dîners"]; reveal(compose); compose.tap()
        app.buttons["Préparer les repas et les courses"].tap()
        app.tabBars.buttons["Planning"].tap()
        let meal = app.buttons["Nous avons cuisiné ce repas"].firstMatch
        reveal(meal); XCTAssertTrue(meal.exists)
        app.tabBars.buttons["Courses"].tap()
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cocher ")).count, 0)
    }
}


extension DUOUITests {
    func testCoupleLayoutAndReachableActivities() {
        app.tabBars.buttons["Nous"].tap()
        XCTAssertTrue(app.navigationBars["Nous deux"].waitForExistence(timeout: 5))
        let buttons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "coupleIdeaToggle"))
        XCTAssertEqual(buttons.count, 3)
        let identifiers = buttons.allElementsBoundByIndex.map(\.identifier)
        let top = XCTAttachment(screenshot: app.screenshot()); top.name = "Nous-haut"; top.lifetime = .keepAlways; add(top)
        for identifier in identifiers {
            let button = app.buttons[identifier]
            reveal(button); XCTAssertTrue(button.isHittable)
        }
        let bottom = XCTAttachment(screenshot: app.screenshot()); bottom.name = "Nous-bas"; bottom.lifetime = .keepAlways; add(bottom)
    }

    func testManualBudgetPersistsAfterRelaunch() {
        app.tabBars.buttons["Accueil"].tap()
        let budget = app.buttons["openBudget"]
        if !budget.isHittable { app.swipeUp() }
        XCTAssertTrue(budget.waitForExistence(timeout: 5)); budget.tap()
        app.buttons["addBudgetEntry"].tap()
        let amount = app.textFields["budgetAmount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("42,50")
        app.buttons["saveBudgetEntry"].tap()
        XCTAssertTrue(app.staticTexts["budgetRemaining"].waitForExistence(timeout: 5))
        let before = app.staticTexts["budgetRemaining"].label
        app.terminate(); app.launch()
        if !app.buttons["openBudget"].isHittable { app.swipeUp() }
        app.buttons["openBudget"].tap()
        XCTAssertTrue(app.staticTexts["budgetRemaining"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["budgetRemaining"].label, before)
    }
}
