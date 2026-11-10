import XCTest
@testable import DUOCore

final class DailyActionsTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testRepeatCompleteReopenRecompleteAndPersistence() throws {
        var s = Snapshot()
        let row = Record(householdID: s.householdID, payload: .task(HouseTask(title: "Vaisselle", due: now, repeatDays: 7)))
        try s.put(row); try s.completeTask(row, at: now)
        s = try Snapshot.decode(JSONEncoder().encode(s))
        XCTAssertEqual(s.records.filter { !$0.deleted }.count, 2)
        let completed = try XCTUnwrap(s.records.first { $0.id == row.id })
        try s.reopenTask(completed)
        XCTAssertEqual(s.records.filter { !$0.deleted }.count, 1)
        try s.completeTask(try XCTUnwrap(s.records.first { $0.id == row.id }), at: now)
        XCTAssertEqual(s.records.filter { !$0.deleted }.count, 2)
    }
    func testStaleDoubleTapCannotOverwriteFollowingTask() throws {
        var s = Snapshot()
        let row = Record(householdID: s.householdID, payload: .task(HouseTask(title: "Vaisselle", repeatDays: 1)))
        try s.put(row); try s.completeTask(row, at: now)
        let before = s.records
        XCTAssertThrowsError(try s.completeTask(row, at: now.addingTimeInterval(20)))
        XCTAssertEqual(s.records, before)
    }
    func testReopenProtectsModifiedSuccessor() throws {
        var s = Snapshot()
        let row = Record(householdID: s.householdID, payload: .task(HouseTask(title: "Vaisselle", repeatDays: 1)))
        try s.put(row); try s.completeTask(row, at: now)
        var successor = try XCTUnwrap(s.records.first { $0.id != row.id })
        successor.payload = .task(HouseTask(title: "Autre tâche", repeatDays: 1))
        try s.put(successor); let before = s.records
        XCTAssertThrowsError(try s.reopenTask(try XCTUnwrap(s.records.first { $0.id == row.id })))
        XCTAssertEqual(s.records, before)
    }
    func testDeletedRecordCannotBeRecreatedByStaleEditor() throws {
        var s = Snapshot(); let row = Record(householdID: s.householdID, payload: .task(HouseTask(title: "Ancienne")))
        try s.put(row); var deleted = row; deleted.deleted = true; try s.put(deleted)
        XCTAssertThrowsError(try s.current(row))
    }
    func testShoppingMergesUnitsAndPreservesCheckedHistory() throws {
        var s = Snapshot()
        try s.putShopping(Shopping(ingredient: Ingredient("Riz", 1, .kg)))
        try s.putShopping(Shopping(ingredient: Ingredient(" riz ", 500, .g)))
        XCTAssertEqual(s.records.count, 1)
        guard case .shopping(var item) = s.records[0].payload else { return XCTFail() }
        XCTAssertEqual(item.ingredient.quantity, 1.5)
        item.checked = true; var row = s.records[0]; row.payload = .shopping(item); try s.put(row)
        try s.putShopping(Shopping(ingredient: Ingredient("Riz", 1, .kg)))
        XCTAssertEqual(s.records.count, 2)
    }
    func testShoppingRejectsInvalidAndDifferentDimensionsStaySeparate() throws {
        var s = Snapshot()
        XCTAssertThrowsError(try s.putShopping(Shopping(ingredient: Ingredient("Riz", -1, .g))))
        try s.putShopping(Shopping(ingredient: Ingredient("Lait", 1, .l)))
        try s.putShopping(Shopping(ingredient: Ingredient("Lait", 1, .piece)))
        XCTAssertEqual(s.records.count, 2)
    }
    func testUrgentStockRanksRecipeAheadWithoutUsingExpiredStock() {
        let recipes = [Recipe(id: "a", title: "Riz", portions: 2, preparation: 5, cooking: 10, ingredients: [Ingredient("riz", 100, .g)], steps: ["Cuire"], allergens: [], family: "riz"), Recipe(id: "z", title: "Carotte", portions: 2, preparation: 5, cooking: 10, ingredients: [Ingredient("carotte", 100, .g)], steps: ["Cuire"], allergens: [], family: "legume")]
        let stock = [Food(name: "riz", quantity: 100, unit: .g), Food(name: "carotte", quantity: 100, unit: .g, expiry: now.addingTimeInterval(3600))]
        XCTAssertEqual(MealEngine.suggestions(catalog: recipes, stock: stock, exclusions: [], recent: [], now: now).first?.id, "z")
        XCTAssertEqual(MealEngine.suggestions(catalog: recipes, stock: stock, exclusions: ["carotte"], recent: [], now: now).first?.id, "a")
    }
}
