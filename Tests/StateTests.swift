import XCTest
@testable import DUOCore

final class StateTests: XCTestCase {
    func testDarkScheduleCrossesMidnight() { XCTAssertTrue(TimeRules.isDark(minute: 30, start: 1200, end: 420)); XCTAssertTrue(TimeRules.isDark(minute: 1200, start: 1200, end: 420)); XCTAssertFalse(TimeRules.isDark(minute: 420, start: 1200, end: 420)); XCTAssertFalse(TimeRules.isDark(minute: 720, start: 1200, end: 420)) }
    func testDayScheduleAndEqualTimes() { XCTAssertTrue(TimeRules.isDark(minute: 600, start: 500, end: 700)); XCTAssertFalse(TimeRules.isDark(minute: 600, start: 600, end: 600)) }
    func testRecurringTaskSkipsMissedOccurrences() {
        let start = Date(timeIntervalSince1970: 1_700_000_000); let task = HouseTask(title: "Vaisselle", due: start, repeatDays: 1)
        let completed = start.addingTimeInterval(3.5*86400)
        XCTAssertGreaterThan(TimeRules.nextDue(task, completion: completed)!, completed)
    }
    func testDailyRecurrencePreservesLocalTimeAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 9))!
        let next = TimeRules.nextDue(HouseTask(title: "Sortie", due: start, repeatDays: 1), completion: start, calendar: calendar)!
        XCTAssertEqual(calendar.component(.hour, from: next), 9); XCTAssertEqual(next.timeIntervalSince(start), 23*3600)
    }
    func testAdjacentEventsDoNotConflict() { let date = Date(); let a = Event(title: "A", start: date, end: date.addingTimeInterval(60)); let b = Event(title: "B", start: a.end, end: a.end.addingTimeInterval(60)); XCTAssertFalse(a.overlaps(b)) }
    func testOverlappingEventsConflict() { let date = Date(); let a = Event(title: "A", start: date, end: date.addingTimeInterval(120)); let b = Event(title: "B", start: date.addingTimeInterval(60), end: date.addingTimeInterval(180)); XCTAssertTrue(a.overlaps(b)) }
    func testHabitCountsUniqueDays() { var h = Habit(title: "Marcher"); h.completions = [Date(), Date()]; XCTAssertEqual(h.progress(at: Date()), 1) }
    func testCreatedByPersistsInExportAndSync() throws {
        let author = UUID(); let home = UUID()
        let row = Record(householdID: home, createdBy: author, payload: .task(HouseTask(title: "Partage")))
        let restored = try JSONDecoder().decode(Record.self, from: JSONEncoder().encode(row))
        XCTAssertEqual(restored.createdBy, author)
    }
    func testLegacyRecordWithoutCreatedByIsReadable() throws {
        let home = UUID(); let row = Record(householdID: home, payload: .task(HouseTask(title: "Ancienne tâche")))
        let data = try JSONEncoder().encode(row)
        let restored = try JSONDecoder().decode(Record.self, from: data)
        XCTAssertNil(restored.createdBy)
    }
    func testTombstoneWithRedactedValidPayload() throws {
        var snapshot = Snapshot(); var row = Record(householdID: snapshot.householdID, payload: .task(HouseTask(title: "Photo privée")))
        row.deleted = true; row.revision = 2; row.payload = .task(HouseTask(title: "Élément supprimé"))
        snapshot.receive(row)
        let decoded = try Snapshot.decode(JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.records.count, 1)
        XCTAssertTrue(decoded.records[0].deleted)
        XCTAssertEqual(decoded.records[0].payload, .task(HouseTask(title: "Élément supprimé")))
    }
    func testSnapshotRoundTripPreservesOutbox() throws { var s = Snapshot(); let r = Record(householdID: s.householdID, payload: .food(Food(name: "riz", quantity: 100, unit: .g))); try s.put(r); let decoded = try Snapshot.decode(JSONEncoder().encode(s)); XCTAssertEqual(decoded.pending, [r.id]); XCTAssertEqual(decoded.records, [r]) }
    func testFutureSchemaDoesNotResetData() throws { var s = Snapshot(); s.schema = 999; XCTAssertThrowsError(try Snapshot.decode(JSONEncoder().encode(s))) }
    func testCorruptedSnapshotRejected() { XCTAssertThrowsError(try Snapshot.decode(Data("broken".utf8))) }
    func testForeignHouseholdRejected() { var s = Snapshot(); XCTAssertThrowsError(try s.put(Record(householdID: UUID(), payload: .habit(Habit(title: "Private"))))) }
    func testForeignOwnerRejected() { var s = Snapshot(); XCTAssertThrowsError(try s.put(Record(householdID: s.householdID, ownerID: UUID(), payload: .habit(Habit(title: "Private"))))) }
    func testRemoteForeignPrivateDataIgnored() { var s = Snapshot(); s.receive(Record(householdID: s.householdID, ownerID: UUID(), payload: .habit(Habit(title: "Private")))); XCTAssertTrue(s.records.isEmpty) }
    func testConcurrentEditsPreserveBothVersions() throws {
        var s = Snapshot(); var local = Record(householdID: s.householdID, payload: .food(Food(name: "riz", quantity: 100, unit: .g))); local.revision = 1; try s.put(local)
        var remote = local; remote.revision = 2; remote.payload = .food(Food(name: "riz", quantity: 200, unit: .g)); s.receive(remote)
        XCTAssertEqual(s.records[0], local); XCTAssertEqual(s.conflicts[0].local, local); XCTAssertEqual(s.conflicts[0].remote, remote)
    }
    func testRemoteDeletionPropagates() { var s = Snapshot(); var r = Record(householdID: s.householdID, payload: .habit(Habit(title: "Marche"))); r.revision = 1; s.receive(r); r.deleted = true; r.revision = 2; s.receive(r); XCTAssertTrue(s.records[0].deleted) }
    func testOfflineEditsCoalesceByRecordID() throws { var s = Snapshot(); let r = Record(householdID: s.householdID, payload: .habit(Habit(title: "Marche"))); try s.put(r); try s.put(r); XCTAssertEqual(s.pending.count, 1) }
    func testCatalogHasUsableInstructionsAndUnits() throws { XCTAssertEqual(Set(Catalog.recipes.map(\.id)).count, Catalog.recipes.count); for r in Catalog.recipes { XCTAssertGreaterThan(r.steps.count, 1); XCTAssertGreaterThan(r.ingredients.count, 2); XCTAssertGreaterThan(r.portions, 0); for i in r.ingredients { try Food(name: i.name, quantity: i.quantity, unit: i.unit).validate() } } }
}

extension StateTests {
    func testConcurrentCompletionGetsSameSuccessorID() {
        let id = UUID(); XCTAssertEqual(TimeRules.nextTaskID(id), TimeRules.nextTaskID(id)); XCTAssertNotEqual(TimeRules.nextTaskID(id),id)
        XCTAssertNotEqual(TimeRules.nextTaskID(TimeRules.nextTaskID(id)),id)
    }
    func testDecodedNegativeStockIsRejected() throws {
        var s = Snapshot(); s.records = [Record(householdID: s.householdID, payload: .food(Food(name: "riz", quantity: -1, unit: .g)))]
        XCTAssertThrowsError(try Snapshot.decode(JSONEncoder().encode(s)))
    }
}

extension StateTests {
    func testCoupleRotationAcrossMidnightAndDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 23, minute: 59)))
        let next = day.addingTimeInterval(120)
        let a = CoupleSchedule.indices(on: day, count: 28, calendar: calendar)
        let b = CoupleSchedule.indices(on: next, count: 28, calendar: calendar)
        XCTAssertEqual(Set(a).count, 3)
        XCTAssertTrue(Set(a).isDisjoint(with: b))
        XCTAssertNotEqual(CoupleSchedule.dayKey(day, calendar: calendar), CoupleSchedule.dayKey(next, calendar: calendar))
        let later = next.addingTimeInterval(12 * 3600)
        XCTAssertEqual(b, CoupleSchedule.indices(on: later, count: 28, calendar: calendar))
    }
    func testLegacyBackupAndCoupleValidationRoundTrip() throws {
        var s = Snapshot()
        let legacy = try JSONEncoder().encode(s)
        XCTAssertNil(try Snapshot.decode(legacy).coupleDay)
        s.coupleDay = "2026-11-05"; s.coupleCompleted = [1, 2]
        let restored = try Snapshot.decode(JSONEncoder().encode(s))
        XCTAssertEqual(restored.coupleDay, s.coupleDay)
        XCTAssertEqual(restored.coupleCompleted, s.coupleCompleted)
    }
}
