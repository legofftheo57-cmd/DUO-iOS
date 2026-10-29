import XCTest
@testable import DUOCore

final class EngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_793_232_000)
    func testKilogramsToGrams() throws { XCTAssertEqual(try FoodUnit.kg.convert(0.5, to: .g), 500) }
    func testLitersToMilliliters() throws { XCTAssertEqual(try FoodUnit.l.convert(0.2, to: .ml), 200) }
    func testMassCannotBecomeVolume() { XCTAssertThrowsError(try FoodUnit.g.convert(50, to: .ml)) }
    func testNegativeQuantityRejected() { XCTAssertThrowsError(try Food(name: "riz", quantity: -1, unit: .g).validate()) }
    func testNaNRejected() { XCTAssertThrowsError(try Food(name: "riz", quantity: .nan, unit: .g).validate()) }
    func testZeroAllowed() throws { try Food(name: "riz", quantity: 0, unit: .g).validate() }
    func testFractionalPiecesRejected() { XCTAssertThrowsError(try Food(name: "œufs", quantity: 0.5, unit: .piece).validate()) }
    func testEmptyNameRejected() { XCTAssertThrowsError(try Food(name: "  ", quantity: 1, unit: .g).validate()) }
    func testNormalization() { XCTAssertEqual(normalized("  ÉPINARDS "), "epinards") }
    func testPortionScaling() throws {
        let r = Catalog.recipes.first(where: { $0.id == "rice" })!
        let needs = try MealEngine.requirements([Meal(recipeID: r.id, date: now, portions: 4)], catalog: Catalog.recipes)
        XCTAssertEqual(needs.first { $0.name == "riz" }?.quantity, 320)
        XCTAssertEqual(needs.first { $0.name == "œufs" }?.quantity, 6)
    }
    func testWholeEggRounding() throws {
        let needs = try MealEngine.requirements([Meal(recipeID: "rice", date: now, portions: 1)], catalog: Catalog.recipes)
        XCTAssertEqual(needs.first { $0.name == "œufs" }?.quantity, 2)
    }
    func testUnknownRecipeFails() { XCTAssertThrowsError(try MealEngine.requirements([Meal(recipeID: "absent", date: now)], catalog: Catalog.recipes)) }
    func testInvalidPortionsFail() { XCTAssertThrowsError(try MealEngine.requirements([Meal(recipeID: "rice", date: now, portions: 0)], catalog: Catalog.recipes)) }
    func testStockDeductedOnceAcrossMeals() throws {
        let meals = [Meal(recipeID: "rice", date: now), Meal(recipeID: "rice", date: now)]
        let needs = try MealEngine.requirements(meals, catalog: Catalog.recipes)
        let missing = MealEngine.missing(needs, stock: [Food(name: "riz", quantity: 200, unit: .g)], now: now)
        XCTAssertEqual(missing.first { $0.name == "riz" }?.quantity, 120)
    }
    func testStockUnitsConverted() { XCTAssertTrue(MealEngine.missing([Ingredient("riz", 400, .g)], stock: [Food(name: "riz", quantity: 0.5, unit: .kg)], now: now).isEmpty) }
    func testIncompatibleStockDoesNotSatisfy() { XCTAssertEqual(MealEngine.missing([Ingredient("riz", 400, .g)], stock: [Food(name: "riz", quantity: 4, unit: .piece)], now: now).first?.quantity, 400) }
    func testExpiredFoodExcluded() { XCTAssertEqual(MealEngine.missing([Ingredient("riz", 50, .g)], stock: [Food(name: "riz", quantity: 100, unit: .g, expiry: now.addingTimeInterval(-86400))], now: now).count, 1) }
    func testTwoLotsAggregated() { XCTAssertTrue(MealEngine.missing([Ingredient("riz", 400, .g)], stock: [Food(name: "riz", quantity: 200, unit: .g), Food(name: "riz", quantity: 0.2, unit: .kg)], now: now).isEmpty) }
    func testCookedMealsExcluded() throws { var m = Meal(recipeID: "rice", date: now); m.cooked = true; XCTAssertTrue(try MealEngine.requirements([m], catalog: Catalog.recipes).isEmpty) }
    func testAllergenExclusions() { XCTAssertFalse(MealEngine.suggestions(catalog: Catalog.recipes, stock: [], exclusions: ["lait"], recent: []).contains { $0.allergens.contains("lait") }) }
    func testIngredientExclusions() { XCTAssertFalse(MealEngine.suggestions(catalog: Catalog.recipes, stock: [], exclusions: ["poulet"], recent: []).contains { $0.id == "chicken" }) }
    func testPlanDoesNotRepeat() throws { let meals = try MealEngine.plan(count: 5, portions: 2, start: now, catalog: Catalog.recipes, stock: [], exclusions: [], recent: [], budget: 35, prices: []); XCTAssertEqual(meals.count, 5); XCTAssertEqual(Set(meals.map(\.recipeID)).count, 5) }
    func testMissingPricesAreUnknown() { XCTAssertNil(MealEngine.cost([Ingredient("riz", 200, .g)], prices: [], now: now)) }
    func testPackRounding() { let p = PurchasePrice(key: "riz|mass", packQuantity: 500, unit: .g, euros: 2, observed: now, source: "Saisie test"); XCTAssertEqual(MealEngine.cost([Ingredient("riz", 600, .g)], prices: [p], now: now), 4) }
    func testStalePricesUnknown() { let p = PurchasePrice(key: "riz|mass", packQuantity: 500, unit: .g, euros: 2, observed: now.addingTimeInterval(-8*86400), source: "Test"); XCTAssertNil(MealEngine.cost([Ingredient("riz", 600, .g)], prices: [p], now: now)) }
    func testFuturePricesUnknown() { let p = PurchasePrice(key: "riz|mass", packQuantity: 500, unit: .g, euros: 2, observed: now.addingTimeInterval(100), source: "Test"); XCTAssertNil(MealEngine.cost([Ingredient("riz", 1, .g)], prices: [p], now: now)) }
    func testConsumeEarliestExpiryFirst() throws {
        let home = UUID(); let first = Record(householdID: home, payload: .food(Food(name: "riz", quantity: 100, unit: .g, expiry: now.addingTimeInterval(86400))))
        let second = Record(householdID: home, payload: .food(Food(name: "riz", quantity: 100, unit: .g, expiry: now.addingTimeInterval(3*86400))))
        let result = try MealEngine.consume([Ingredient("riz", 150, .g)], stock: [second, first], now: now)
        if case .food(let f) = result[0].payload { XCTAssertEqual(f.quantity, 50) } else { XCTFail() }
        if case .food(let f) = result[1].payload { XCTAssertEqual(f.quantity, 0) } else { XCTFail() }
    }
    func testConsumeIsAtomicOnInsufficientStock() { let row = Record(householdID: UUID(), payload: .food(Food(name: "riz", quantity: 100, unit: .g))); XCTAssertThrowsError(try MealEngine.consume([Ingredient("riz", 200, .g)], stock: [row], now: now)); if case .food(let f) = row.payload { XCTAssertEqual(f.quantity, 100) } }
}

extension EngineTests {
    func testExpiryRespectedAtFutureMealDate() throws {
        let future = now.addingTimeInterval(3*86400)
        let missing = try MealEngine.missingForMeals([Meal(recipeID: "rice", date: future)], catalog: Catalog.recipes, stock: [Food(name: "riz", quantity: 1000, unit: .g, expiry: now.addingTimeInterval(86400))])
        XCTAssertEqual(missing.first { $0.name == "riz" }?.quantity, 160)
    }
    func testDatedMealsCannotReuseSameStock() throws {
        let missing = try MealEngine.missingForMeals([Meal(recipeID: "rice", date: now), Meal(recipeID: "rice", date: now.addingTimeInterval(86400))], catalog: Catalog.recipes, stock: [Food(name: "riz", quantity: 200, unit: .g)])
        XCTAssertEqual(missing.first { $0.name == "riz" }?.quantity, 120)
    }
}
