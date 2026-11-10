import XCTest
@testable import DUOCore

final class FinanceLedgerTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func account(_ id: String, _ type: FinancialAccountType, _ cents: Int64,
                 source: FinancialDataSource = .bank, hoursOld: TimeInterval = 1) -> FinancialAccountSnapshot {
        FinancialAccountSnapshot(id: id, ownerID: "owner", type: type, source: source,
                                 balanceCents: cents, observedAt: now.addingTimeInterval(-hoursOld * 3600))
    }

    func calculate(_ accounts: [FinancialAccountSnapshot],
                   _ tx: [FinancialTransaction] = [],
                   _ goals: [FinancialGoalAllocation] = []) throws -> FinanceLedgerSummary {
        try FinanceLedger.summarize(accounts: accounts, transactions: tx, allocations: goals, now: now)
    }

    func testBankDepositsAndSavingsNotDoubleCounted() throws {
        let x = try calculate([account("a", .checking, 120_000), account("b", .savings, 90_000)],
                              [], [FinancialGoalAllocation(goalID: "holiday", accountID: "b", reservedCents: 50_000)])
        XCTAssertEqual(x.checkingCents, 120_000)
        XCTAssertEqual(x.savingsCents, 90_000)
        XCTAssertEqual(x.allocatedCents, 50_000)
        XCTAssertEqual(x.unallocatedDepositsCents, 160_000)
    }

    func testCETDoesNotBecomeSpendable() throws {
        let x = try calculate([account("bank", .checking, 5_000),
                               account("cet", .deferredGrossCET, 85_480, source: .manual)])
        XCTAssertEqual(x.checkingCents, 5_000)
        XCTAssertEqual(x.deferredCETGrossCents, 85_480)
        XCTAssertEqual(x.unallocatedDepositsCents, 5_000)
    }

    func testInternalTransferAndPendingNotExpenses() throws {
        let bank = account("a", .checking, 100_000)
        let tx: [FinancialTransaction] = [
            .init(accountID: "a", providerTransactionID: "transfer", amountCents: -2_000, kind: .internalTransfer, booked: true),
            .init(accountID: "a", providerTransactionID: "pending", amountCents: -700, kind: .expense, booked: false),
            .init(accountID: "a", providerTransactionID: "spent", amountCents: -1_200, kind: .expense, booked: true),
            .init(accountID: "a", providerTransactionID: "refund", amountCents: 200, kind: .expense, booked: true)
        ]
        let x = try calculate([bank], tx)
        XCTAssertEqual(x.netBookedExpensesCents, 1_000)
        XCTAssertEqual(x.pendingTransactionCount, 1)
    }

    func testDuplicateImportDeduplicated() throws {
        let t = FinancialTransaction(accountID: "a", providerTransactionID: "123",
                                     amountCents: -1_000, kind: .expense, booked: true)
        let x = try calculate([account("a", .checking, 10_000)], [t,t])
        XCTAssertEqual(x.netBookedExpensesCents, 1_000)
    }

    func testConflictingDuplicateRejected() {
        XCTAssertThrowsError(try calculate([account("a", .checking, 10_000)], [
            .init(accountID: "a", providerTransactionID: "1", amountCents: -1_000, kind: .expense, booked: true),
            .init(accountID: "a", providerTransactionID: "1", amountCents: -2_000, kind: .expense, booked: true)
        ])) { XCTAssertEqual($0 as? FinanceLedgerError, .duplicateTransactionConflict) }
    }

    func testCannotReserveMoreThanExistingMoney() {
        XCTAssertThrowsError(try calculate([account("a", .checking, 2_000)], [], [
            .init(goalID: "goal", accountID: "a", reservedCents: 3_000)
        ])) { XCTAssertEqual($0 as? FinanceLedgerError, .insufficientFunds) }
    }

    func testCannotAllocateFromManualCETOrInvestments() {
        XCTAssertThrowsError(try calculate([account("cet", .deferredGrossCET, 100_000, source: .manual)], [], [
            .init(goalID: "goal", accountID: "cet", reservedCents: 10_000)
        ])) { XCTAssertEqual($0 as? FinanceLedgerError, .invalidData) }
    }

    func testStaleStatusNotSilentlyCurrent() throws {
        let x = try calculate([account("old", .checking, 1_000, hoursOld: 30),
                               account("new", .savings, 2_000)])
        XCTAssertEqual(x.staleAccountIDs, ["old"])
    }

    func testDuplicateAccountsRejected() {
        XCTAssertThrowsError(try calculate([account("same", .checking, 1),
                                            account("same", .checking, 1)])) {
            XCTAssertEqual($0 as? FinanceLedgerError, .duplicateAccount)
        }
    }

    func testNonEuroBalancesRejected() {
        let gbp = FinancialAccountSnapshot(id: "a", ownerID: "x", type: .checking, source: .bank,
                                           balanceCents: 10, currency: "GBP", observedAt: now)
        XCTAssertThrowsError(try calculate([gbp])) {
            XCTAssertEqual($0 as? FinanceLedgerError, .unsupportedCurrency)
        }
    }

    func testOverflowRejected() {
        XCTAssertThrowsError(try calculate([account("a", .checking, Int64.max),
                                            account("b", .savings, 2)])) {
            XCTAssertEqual($0 as? FinanceLedgerError, .amountOverflow)
        }
    }
}
