import XCTest
@testable import DUOCore

final class BrainTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Paris")!; return c }()
    func date(_ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    func testShiftRotation() {
        XCTAssertFalse(DuoSchedule.isMorningWeek(date(18), calendar: cal))     // semaine du soir (16 nov.)
        XCTAssertTrue(DuoSchedule.isMorningWeek(date(24), calendar: cal))      // semaine du matin (23 nov.)
        XCTAssertFalse(DuoSchedule.isMorningWeek(date(30), calendar: cal))     // semaine du soir (30 nov.)
        XCTAssertEqual(DuoSchedule.work(.theo, on: date(24), calendar: cal)?.start, 5 * 60 + 28)
        XCTAssertEqual(DuoSchedule.work(.lilou, on: date(27), calendar: cal)?.end, 16 * 60)   // vendredi
        XCTAssertNil(DuoSchedule.work(.theo, on: date(28), calendar: cal))                    // samedi
    }
    func testEnergyAndCook() {
        XCTAssertLessThanOrEqual(DuoSchedule.energy(.theo, on: date(24), calendar: cal), 1)
        XCTAssertEqual(DuoSchedule.energy(.theo, on: date(28), calendar: cal), 3)
        XCTAssertEqual(DuoSchedule.cook(on: date(24), calendar: cal), .theo)     // libre dès 13 h 30
        XCTAssertEqual(DuoSchedule.cook(on: date(18), calendar: cal), .lilou)    // Théo rentre après 21 h
    }
    func testLeftoversComeFirst() {
        let rest = Food(name: "Restes : Gratin", quantity: 2, unit: .piece, category: Brain.leftoverCategory, expiry: date(26))
        let p = Brain.proposals(now: date(24, 9), me: .theo, foods: [rest], meals: [], tasks: [], shopping: [], journal: [], dismissedToday: [], calendar: cal)
        XCTAssertEqual(p.first?.family, "leftover")
        XCTAssertFalse(p.contains { $0.family == "tonight" })
    }
    func testDismissedAndMuted() {
        let base = Brain.proposals(now: date(24, 9), me: .theo, foods: [], meals: [], tasks: [], shopping: [], journal: [], dismissedToday: [], calendar: cal)
        XCTAssertFalse(base.isEmpty)
        let ids = Set(base.map(\.id))
        XCTAssertTrue(Brain.proposals(now: date(24, 9), me: .theo, foods: [], meals: [], tasks: [], shopping: [], journal: [], dismissedToday: ids, calendar: cal).isEmpty)
        let declines = (0..<3).map { JournalEntry(kind: .declined, title: "x", person: "Théo", date: date(20 + $0), ref: "week") }
        XCTAssertFalse(Brain.proposals(now: date(24, 9), me: .theo, foods: [], meals: [], tasks: [], shopping: [], journal: declines, dismissedToday: [], calendar: cal).contains { $0.family == "week" })
    }
    func testHabitsAndRooms() {
        let j = [1, 8, 15].map { JournalEntry(kind: .bought, title: "Lait", person: "Lilou", date: date($0)) }
        XCTAssertEqual(Brain.restockInterval("lait", journal: j), 7)
        XCTAssertEqual(Brain.room(for: "Vaisselle du soir"), 0)
        XCTAssertEqual(Brain.room(for: "Changer les draps"), 2)
        XCTAssertEqual(Brain.room(for: "Nettoyer le lavabo"), 3)
        XCTAssertEqual(Brain.room(for: "Aspirateur salon"), 1)
        let done = [JournalEntry(kind: .taskDone, title: "a", person: "Théo", date: date(23)), JournalEntry(kind: .taskDone, title: "b", person: "Lilou", date: date(23))]
        XCTAssertEqual(Brain.balance(done, now: date(24)), 50)
    }
    func testCatalogCostsCoverEveryRecipe() {
        for r in Catalog.recipes { XCTAssertNotNil(Catalog.cost[r.id], r.id) }
    }
}
