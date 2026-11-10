import XCTest
@testable import DUO
import DUOCore

@MainActor final class AppStoreTests: XCTestCase {
    func fresh() -> AppStore { AppStore(scopeOverride: "unit-" + UUID().uuidString) }
    func testTaskCompletionReopenAndRecurringProtection() throws {
        let store = fresh()
        store.put(.task(HouseTask(title: "Vaisselle", repeatDays: 1)))
        let original = try XCTUnwrap(store.records.first)
        store.toggle(original)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.records.count, 2)
        let done = try XCTUnwrap(store.records.first { $0.id == original.id })
        store.reopenTask(done)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.records.count, 1)
        guard case .task(let task) = store.records[0].payload else { return XCTFail() }
        XCTAssertNil(task.completed)
        store.toggle(store.records[0])
        let successor = try XCTUnwrap(store.records.first { $0.id != original.id })
        store.put(.task(HouseTask(title: "Déjà modifiée", repeatDays: 1)), editing: successor)
        store.reopenTask(try XCTUnwrap(store.records.first { $0.id == original.id }))
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.records.count, 2)
    }
    func testAllRecordKindsPersistAfterReopeningStore() throws {
        let scope = "unit-" + UUID().uuidString
        let store = AppStore(scopeOverride: scope)
        let start = Date()
        let contents: [Content] = [.task(HouseTask(title: "Tâche")), .food(Food(name: "riz", quantity: 1, unit: .kg)), .shopping(Shopping(ingredient: Ingredient("pain", 1, .piece))), .event(Event(title: "Rendez-vous", start: start, end: start.addingTimeInterval(3600))), .habit(Habit(title: "Marche")), .meal(Meal(recipeID: Catalog.recipes[0].id, date: start))]
        for content in contents { store.put(content); XCTAssertNil(store.error) }
        store.transact { $0.coupleDay = "2026-11-05"; $0.coupleCompleted = [0, 1] }
        let reopened = AppStore(scopeOverride: scope)
        XCTAssertTrue(reopened.ready)
        XCTAssertEqual(reopened.snapshot.records, store.snapshot.records)
        XCTAssertEqual(reopened.snapshot.coupleCompleted, [0, 1])
    }
    func testExportRestoreAndSafetyCopy() throws {
        let store = fresh()
        store.put(.task(HouseTask(title: "Avant export")))
        store.transact { $0.coupleDay = "2026-11-05"; $0.coupleCompleted = [2] }
        let export = try store.prepareExport()
        let imported = try store.previewLocalImport(from: export)
        store.put(.shopping(Shopping(ingredient: Ingredient("À préserver", 1, .piece))))
        let previous = store.snapshot
        let safety = try store.restoreLocalImport(imported)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.snapshot.coupleCompleted, [2])
        let recovery = try store.previewLocalImport(from: safety)
        XCTAssertEqual(recovery.records, previous.records)
        XCTAssertEqual(store.safetyBackupURL, safety)
        try store.restoreLocalImport(recovery)
        XCTAssertEqual(store.records.count, 2)
    }
    func testInvalidImportAndInvalidWritePreserveData() throws {
        let store = fresh(); store.put(.task(HouseTask(title: "À conserver")))
        let before = store.snapshot.records
        store.put(.food(Food(name: "riz", quantity: -1, unit: .kg)))
        XCTAssertNotNil(store.error); XCTAssertEqual(store.snapshot.records, before)
        var invalid = store.snapshot; invalid.schema = 999
        XCTAssertThrowsError(try store.restoreLocalImport(invalid))
        XCTAssertEqual(store.snapshot.records, before)
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("not json".utf8).write(to: bad)
        XCTAssertThrowsError(try store.previewLocalImport(from: bad))
        XCTAssertEqual(store.snapshot.records, before)
    }
    func testShoppingEditCheckDeleteAndHabitUndo() throws {
        let store = fresh()
        store.put(.shopping(Shopping(ingredient: Ingredient("Riz", 1, .kg))))
        store.toggle(try XCTUnwrap(store.records.first))
        guard case .shopping(let item) = store.records[0].payload else { return XCTFail() }
        XCTAssertTrue(item.checked)
        store.remove(store.records[0]); XCTAssertTrue(store.records.isEmpty)
        store.put(.habit(Habit(title: "Marcher")), isPrivate: true)
        store.toggle(store.records[0])
        guard case .habit(let habit) = store.records[0].payload else { return XCTFail() }
        XCTAssertEqual(habit.progress(at: Date()), 1)
        store.toggle(store.records[0])
        guard case .habit(let undone) = store.records[0].payload else { return XCTFail() }
        XCTAssertEqual(undone.progress(at: Date()), 0)
    }

    func testBudgetAndBalancesPersistAndExportWithHouseholdData() throws {
        let scope = "unit-" + UUID().uuidString
        let store = AppStore(scopeOverride: scope)
        store.transact {
            $0.manualBudget = [.init(date: Date(), kind: .expense, cents: 2000, title: "Courses", person: "Lilou", shared: true)]
            $0.manualAccounts = [.init(name: "CIC", type: .checking, cents: 10000, observedAt: Date())]
        }
        XCTAssertNil(store.error)
        let reopened = AppStore(scopeOverride: scope)
        XCTAssertEqual(reopened.snapshot.manualBudget, store.snapshot.manualBudget)
        XCTAssertEqual(reopened.snapshot.manualAccounts, store.snapshot.manualAccounts)
        let backup = try store.previewLocalImport(from: store.prepareExport())
        store.transact { $0.manualBudget = []; $0.manualAccounts = [] }
        try store.restoreLocalImport(backup)
        XCTAssertEqual(store.snapshot.manualBudget, backup.manualBudget)
        XCTAssertEqual(store.snapshot.manualAccounts, backup.manualAccounts)
    }
    func testCookingStaleConfirmationNeverConsumesTwice() throws {
        let store = fresh()
        let recipe = try XCTUnwrap(Catalog.recipes.first)
        for ingredient in recipe.ingredients {
            store.put(.food(Food(name: ingredient.name, quantity: ingredient.quantity * 3, unit: ingredient.unit)))
        }
        let meal = Meal(recipeID: recipe.id, date: Date(), portions: recipe.portions)
        store.put(.meal(meal))
        let row = try XCTUnwrap(store.records.first { if case .meal = $0.payload { return true }; return false })
        store.cook(row); XCTAssertNil(store.error)
        let stocks = store.foods
        store.cook(row)
        XCTAssertNotNil(store.error); XCTAssertEqual(store.foods, stocks)
    }
    func testMealDateAndPortionsRebuildShoppingAtomically() throws {
        let store = fresh(), recipe = try XCTUnwrap(Catalog.recipes.first)
        store.put(.meal(Meal(recipeID: recipe.id, date: Date(), portions: 2)))
        XCTAssertNil(store.error)
        let row = try XCTUnwrap(store.records.first { if case .meal = $0.payload { return true }; return false })
        var changed = Meal(recipeID: recipe.id, date: Date().addingTimeInterval(86400), portions: 4)
        store.put(.meal(changed), editing: row); XCTAssertNil(store.error)
        let before = store.snapshot.records
        changed.portions = 0
        let current = try XCTUnwrap(store.records.first { $0.id == row.id })
        store.put(.meal(changed), editing: current)
        XCTAssertNotNil(store.error); XCTAssertEqual(store.snapshot.records, before)
    }

    func testLegacyRestoreKeepsLocalFinancialData() throws {
        let store = fresh()
        let oldBackup = store.snapshot
        store.transact { $0.manualBudget = [.init(date: Date(), kind: .income, cents: 1000, title: "Salaire", person: "Théo")] }
        let budget = store.snapshot.manualBudget
        try store.restoreLocalImport(oldBackup)
        XCTAssertEqual(store.snapshot.manualBudget, budget)
    }
}
