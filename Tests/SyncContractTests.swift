import Foundation
import XCTest
@testable import DUOCore

final class SyncContractTests: XCTestCase {
    private func item(_ home: UUID, owner: UUID? = nil, rev: Int = 1, title: String = "Courses") -> Record {
        var row = Record(householdID: home, ownerID: owner, payload: .task(HouseTask(title: title)))
        row.revision = rev
        return row
    }
    func testEmptyServerSnapshotIsValid() throws {
        try SyncContract.validateFetched([], for: Snapshot())
    }
    func testDuplicateFetchedIDsRejected() {
        let snapshot = Snapshot()
        let row = item(snapshot.householdID)
        XCTAssertThrowsError(try SyncContract.validateFetched([row, row], for: snapshot))
    }
    func testForeignHouseholdAndForeignPrivateRowsRejected() {
        let snapshot = Snapshot()
        XCTAssertThrowsError(try SyncContract.validateFetched([item(UUID())], for: snapshot))
        XCTAssertThrowsError(try SyncContract.validateFetched([item(snapshot.householdID,owner:UUID())], for: snapshot))
    }
    func testInvalidFetchedValuesRejected() {
        let snapshot = Snapshot()
        XCTAssertThrowsError(try SyncContract.validateFetched([item(snapshot.householdID,rev:0)], for: snapshot))
        XCTAssertThrowsError(try SyncContract.validateFetched([item(snapshot.householdID,title:"")], for: snapshot))
    }
    func testAcknowledgementValidForSingleWrite() throws {
        let snapshot = Snapshot()
        let local = item(snapshot.householdID,rev:0)
        var saved = local; saved.revision = 1
        try SyncContract.validateAcknowledged([saved], pending:[local], for:snapshot)
    }
    func testEmptyAndPartialAcknowledgementRejected() {
        let snapshot = Snapshot()
        let a = item(snapshot.householdID,rev:0)
        let b = item(snapshot.householdID,rev:0)
        var saved = a; saved.revision = 1
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([], pending:[a], for:snapshot))
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([saved], pending:[a,b], for:snapshot))
    }
    func testAcknowledgementDuplicateAndForeignRejected() {
        let snapshot = Snapshot()
        let a = item(snapshot.householdID,rev:0)
        var saved = a; saved.revision = 1
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([saved,saved], pending:[a,a], for:snapshot))
        var foreign = saved; foreign.householdID = UUID()
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([foreign], pending:[a], for:snapshot))
    }
    func testAcknowledgementDoesNotAcceptDifferentPayloadOrRevision() {
        let snapshot = Snapshot()
        let local = item(snapshot.householdID,rev:3)
        var saved = local; saved.revision = 4
        saved.payload = .task(HouseTask(title:"Autre chose"))
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([saved], pending:[local], for:snapshot))
        saved.payload = local.payload; saved.revision = 3
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([saved], pending:[local], for:snapshot))
    }
    func testAcknowledgementPreservesDeletionState() {
        let snapshot = Snapshot()
        var local = item(snapshot.householdID,rev:2); local.deleted = true
        var saved = local; saved.revision = 3; saved.deleted = false
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([saved], pending:[local], for:snapshot))
    }
    func testMaxRevisionAcknowledgementFailsSafely() {
        let snapshot = Snapshot()
        let local = item(snapshot.householdID, rev:Int.max)
        XCTAssertThrowsError(try SyncContract.validateAcknowledged([local], pending:[local], for:snapshot))
    }
}
