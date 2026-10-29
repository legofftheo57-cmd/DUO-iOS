import XCTest
@testable import DUOCore

final class AssistantTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_793_232_000)
    func testInviteIsOneTimeTokenShape() {
        let token = UUID().uuidString + UUID().uuidString
        XCTAssertTrue(InviteLink.valid(token))
        XCTAssertEqual(InviteLink.read(InviteLink.make(token: token)!), token)
    }
    func testRejectsWrongSchemeAndExtraParameters() {
        let token = UUID().uuidString + UUID().uuidString
        XCTAssertNil(InviteLink.read(URL(string: "https://example.com/invite?token=\(token)")!))
        XCTAssertNil(InviteLink.read(URL(string: "duo://invite?token=\(token)&admin=true")!))
        XCTAssertNil(InviteLink.make(token: "not-a-token"))
    }
    func testReschedulingNeedsUniqueMatch() {
        let home = UUID()
        let rows = [Record(householdID: home, payload: .task(HouseTask(title: "Sport"))), Record(householdID: home, payload: .task(HouseTask(title: "Sport")))]
        let reply = DuoAssistant.answer("Décale le sport à demain", records: rows, recipes: [], stock: [], exclusions: [], now: now)
        XCTAssertNil(reply.action)
    }
    func testEventReschedulingIsProposalOnly() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Paris")!
        let start = cal.date(from: DateComponents(year: 2026,month: 10,day: 29,hour: 9,minute: 30))!
        let row = Record(householdID: UUID(), payload: .event(Event(title: "Sport", start: start, end: start.addingTimeInterval(3600))))
        let reply = DuoAssistant.answer("Décale le sport à demain", records: [row], recipes: [], stock: [], exclusions: [], now: start, calendar: cal)
        if case .moveEvent(let id, let target) = reply.action {
            XCTAssertEqual(id, row.id); XCTAssertEqual(cal.component(.day, from: target), 30)
            XCTAssertEqual(cal.component(.hour, from: target), 9)
        } else { XCTFail("Expected confirmation proposal") }
        if case .event(let unchanged) = row.payload { XCTAssertEqual(unchanged.start, start) } else { XCTFail() }
    }
    func testDeletedItemNotProposed() {
        var row = Record(householdID: UUID(), payload: .task(HouseTask(title: "Sport")))
        row.deleted = true
        XCTAssertNil(DuoAssistant.answer("Reporte le sport à demain", records: [row], recipes: [], stock: [], exclusions: []).action)
    }
    func testBrandsDoNotInventLivePrices() {
        let reply = DuoAssistant.answer("Quelle marque de pâtes acheter ?", records: [], recipes: Catalog.recipes, stock: [], exclusions: [])
        XCTAssertNil(reply.action)
        XCTAssertTrue(reply.message.contains("prix actuels"))
    }
    func testRecipeSuggestionsHonorExclusions() {
        let reply = DuoAssistant.answer("Que cuisiner comme recette ?", records: [], recipes: Catalog.recipes, stock: [], exclusions: ["lait"])
        XCTAssertNil(reply.action)
        XCTAssertTrue(reply.message.contains("recettes"))
    }
    func testJoeCanProposeGroceryItemWithoutWriting() {
        let answer = DuoAssistant.answer("Ajoute 2 kg de riz aux courses", records: [], recipes: [], stock: [], exclusions: [])
        guard case .addShopping(let item) = answer.action else { return XCTFail("Action expected") }
        XCTAssertEqual(item.name, "riz")
        XCTAssertEqual(item.unit, .kg)
        XCTAssertEqual(item.quantity, 2)
        XCTAssertTrue(answer.message.contains("confirmation"))
    }
    func testJoeCanProposeUnquantifiedMilk() {
        let answer = DuoAssistant.answer("Mets du lait sur la liste de courses", records: [], recipes: [], stock: [], exclusions: [])
        guard case .addShopping(let item) = answer.action else { return XCTFail("Expected grocery action") }
        XCTAssertEqual(item.name, "lait")
        XCTAssertEqual(item.quantity, 1)
        XCTAssertEqual(item.unit, .piece)
    }
    func testJoeRejectsUnsafeQuantity() {
        let reply = DuoAssistant.answer("Ajoute 1,5 pièces de lait aux courses", records: [], recipes: [], stock: [], exclusions: [])
        XCTAssertNil(reply.action)
    }
    func testJoeNeverActsOnShoppingQuestion() {
        let reply = DuoAssistant.answer("Quelles courses prévoir ?", records: [], recipes: [], stock: [], exclusions: [])
        XCTAssertNil(reply.action)
    }
    func testJoeRejectsEmptyGroceryName() {
        let reply = DuoAssistant.answer("Ajoute aux courses", records: [], recipes: [], stock: [], exclusions: [])
        XCTAssertNil(reply.action)
    }
    func testJoeRejectsHugeQuantity() {
        let reply = DuoAssistant.answer("Ajoute 999999999 kg de riz aux courses", records: [], recipes: [], stock: [], exclusions: [])
        XCTAssertNil(reply.action)
    }
    func testLongQuestionIsRejectedWithoutAction() {
        XCTAssertNil(DuoAssistant.answer(String(repeating: "x",count: 900),records:[], recipes:[], stock:[],exclusions:[]).action)
    }
}
