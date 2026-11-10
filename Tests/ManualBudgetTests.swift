import XCTest
@testable import DUOCore

final class ManualBudgetTests: XCTestCase {
    func testStrictMoneyInput() {
        XCTAssertEqual(ManualBudget.amountInCents(" 42,50 "), 4250)
        XCTAssertEqual(ManualBudget.amountInCents("0.01"), 1)
        XCTAssertEqual(ManualBudget.amountInCents("1000000"), 100000000)
        for text in ["-1", "1e5", "NaN", "1.001", "1.", "0", "1000000.01", "1 000", "+1", "١"] {
            XCTAssertNil(ManualBudget.amountInCents(text), text)
        }
    }
    func testBudgetAndAccountRoundTripWithSnapshot() throws {
        var s = Snapshot()
        s.manualBudget = [.init(date: Date(), kind: .expense, cents: 4250, title: "Courses", person: "Théo", shared: true)]
        s.manualAccounts = [.init(name: "CIC", type: .checking, cents: -1000, observedAt: Date())]
        let restored = try Snapshot.decode(JSONEncoder().encode(s))
        XCTAssertEqual(s.manualBudget, restored.manualBudget)
        XCTAssertEqual(s.manualAccounts, restored.manualAccounts)
    }
    func testOldBackupStillLoads() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Snapshot())) as? [String: Any])
        object.removeValue(forKey: "manualBudget"); object.removeValue(forKey: "manualAccounts")
        let restored = try Snapshot.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.manualBudget); XCTAssertNil(restored.manualAccounts)
    }
    func testDuplicateInvalidOrOverflowingEntriesRejected() throws {
        let entry = BudgetEntry(date: Date(), kind: .expense, cents: 1, title: "Courses", person: "Lilou")
        XCTAssertThrowsError(try ManualBudget.validate([entry,entry]))
        var invalid = entry; invalid.cents = Int.max
        XCTAssertThrowsError(try ManualBudget.validate([invalid]))
        invalid = entry; invalid.shared = true; invalid.kind = .income
        XCTAssertThrowsError(try ManualBudget.validate([invalid]))
    }
    func testManualBalancesExplicitOptInCETAndTransfersSeparated() throws {
        let owner = UUID(), now = Date()
        let accounts: [ManualFinancialAccount] = [
            .init(name: "CIC", type: .checking, cents: 10000, observedAt: now),
            .init(name: "Revolut", type: .checking, cents: 2000, observedAt: now),
            .init(name: "Livret", type: .savings, cents: 3000, observedAt: now),
            .init(name: "CET", type: .deferredGrossCET, cents: 80000, observedAt: now),
            .init(name: "PEA", type: .investment, cents: 50000, observedAt: now)]
        let snapshots = accounts.map { $0.ledgerSnapshot(owner: owner) }
        let sum = try FinanceLedger.summarize(accounts: snapshots, transactions: [], allocations: [], now: now, includeManualBalances: true)
        XCTAssertEqual(sum.checkingCents, 12000); XCTAssertEqual(sum.savingsCents, 3000)
        XCTAssertEqual(sum.unallocatedDepositsCents, 15000); XCTAssertEqual(sum.investmentsCents, 50000)
        XCTAssertEqual(sum.deferredCETGrossCents, 80000)
        let bankOnly = try FinanceLedger.summarize(accounts: snapshots, transactions: [], allocations: [], now: now)
        XCTAssertEqual(bankOnly.checkingCents, 0)
    }
    func testManualBalancesStaleAndInvalidDataRejected() throws {
        let account = ManualFinancialAccount(name: "CIC", type: .checking, cents: 100, observedAt: Date().addingTimeInterval(-90000))
        let sum = try FinanceLedger.summarize(accounts: [account.ledgerSnapshot(owner: UUID())], transactions: [], allocations: [], now: Date(), includeManualBalances: true)
        XCTAssertEqual(sum.staleAccountIDs, [account.id.uuidString])
        XCTAssertThrowsError(try ManualFinancialAccount.validate([account, account]))
        XCTAssertThrowsError(try ManualFinancialAccount.validate([.init(name: "CET", type: .deferredGrossCET, cents: -1, observedAt: Date())]))
    }
}
