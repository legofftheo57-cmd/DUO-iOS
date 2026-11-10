import Foundation
import XCTest
@testable import DUOCore

/// Offline snapshot invariants; tests do not simulate a live Supabase service.
final class SyncSafetyTests: XCTestCase {
    private func task(_ household: UUID, title: String = "Courses") -> Record {
        Record(householdID: household, payload: .task(HouseTask(title: title)))
    }
    func testRemoteOlderRevisionNeverDowngradesLocalCache() throws {
        var snapshot = Snapshot()
        var current = task(snapshot.householdID)
        current.revision = 6
        snapshot.records.append(current)
        var stale = current
        stale.revision = 5
        stale.payload = .task(HouseTask(title: "Ancienne tâche"))
        snapshot.receive(stale)
        XCTAssertEqual(snapshot.records, [current])
        XCTAssertTrue(snapshot.conflicts.isEmpty)
    }
    func testRemoteNewerRevisionUpdatesWithoutPendingChange() {
        var snapshot = Snapshot()
        let base = task(snapshot.householdID)
        snapshot.records.append(base)
        var incoming = base
        incoming.revision = 1
        incoming.payload = .task(HouseTask(title: "Tâche modifiée par mon partenaire"))
        snapshot.receive(incoming)
        XCTAssertEqual(snapshot.records, [incoming])
    }
    func testConcurrentEditPreservesLocalAndRemoteCopies() {
        var snapshot = Snapshot()
        var row = task(snapshot.householdID)
        row.revision = 1
        snapshot.records.append(row)
        row.payload = .task(HouseTask(title: "Édition locale"))
        try? snapshot.put(row)
        var incoming = row
        incoming.revision = 2
        incoming.payload = .task(HouseTask(title: "Édition distante"))
        snapshot.receive(incoming)
        XCTAssertEqual(snapshot.records.first, row)
        XCTAssertEqual(snapshot.conflicts.count, 1)
        XCTAssertEqual(snapshot.conflicts.first?.remote, incoming)
    }
    func testRemoteInvalidPayloadDoesNotPoisonCache() {
        var snapshot = Snapshot()
        let saved = task(snapshot.householdID)
        snapshot.records.append(saved)
        var invalid = saved
        invalid.revision = 2
        invalid.payload = .task(HouseTask(title: ""))
        snapshot.receive(invalid)
        XCTAssertEqual(snapshot.records, [saved])
        XCTAssertTrue(snapshot.conflicts.isEmpty)
    }
    func testForeignPrivateRecordIsNotAdopted() {
        var snapshot = Snapshot()
        let foreign = Record(householdID: snapshot.householdID, ownerID: UUID(), payload: .task(HouseTask(title: "Privé")))
        snapshot.receive(foreign)
        XCTAssertTrue(snapshot.records.isEmpty)
    }
    func testSharedTaskCanBeReceivedBySecondHouseholdMember() {
        let household = UUID()
        let firstUser = UUID(), secondUser = UUID()
        var first = Snapshot(householdID: household, userID: firstUser)
        var second = Snapshot(householdID: household, userID: secondUser)
        var row = task(household, title: "Courses pour nous deux")
        row.revision = 1 // Acknowledged by the server, not a pending local row.
        first.receive(row)
        second.receive(row)
        XCTAssertEqual(first.records, second.records)
        XCTAssertEqual(second.records.first?.payload, row.payload)
    }
    func testRemoteTombstoneRemovesSharedItemWithoutResurrectingIt() {
        var snapshot = Snapshot()
        var row = task(snapshot.householdID, title: "Ancienne tâche")
        row.revision = 1
        snapshot.receive(row)
        row.revision = 2
        row.deleted = true
        snapshot.receive(row)
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertTrue(snapshot.records[0].deleted)
        let visible = snapshot.records.filter { !$0.deleted }
        XCTAssertTrue(visible.isEmpty)
    }
    func testPayloadUsesSchemaExpectedBySupabase() throws {
        let values: [(Content, String, String)] = [
            (.food(Food(name: "Riz", quantity: 2, unit: .kg)), "food", "name"),
            (.shopping(Shopping(ingredient: Ingredient("Pâtes", 1, .kg))), "shopping", "ingredient"),
            (.meal(Meal(recipeID: "recette", date: Date())), "meal", "recipeID"),
            (.task(HouseTask(title: "Courses")), "task", "title"),
            (.event(Event(title: "Sport", start: Date(), end: Date().addingTimeInterval(3600))), "event", "start"),
            (.habit(Habit(title: "Marche")), "habit", "weeklyGoal")
        ]
        for (value, kind, required) in values {
            let data = try JSONEncoder().encode(value)
            let top = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(Set(top.keys), [kind]); let wrapper = try XCTUnwrap(top[kind] as? [String: Any])
            let payload = try XCTUnwrap(wrapper["_0"] as? [String: Any])
            XCTAssertNotNil(payload[required], "SQL valid_payload expects '_0.\(required)' for \(kind)")
            XCTAssertEqual(try JSONDecoder().decode(Content.self, from: data), value)
        }
    }
    func testTitlesLongerThanDatabaseLimitAreRejectedLocally() {
        let title = String(repeating: "A", count: 201)
        XCTAssertThrowsError(try Content.task(HouseTask(title: title)).validate())
        XCTAssertThrowsError(try Content.event(Event(title: title, start: Date(), end: Date().addingTimeInterval(3600))).validate())
        XCTAssertThrowsError(try Content.habit(Habit(title: title)).validate())
    }
}
