import Foundation

/// Pure finance calculations. All amounts use integer EUR cents, never Double.
/// This module never connects to a bank and cannot grant a user access to another user's accounts.
public enum FinancialAccountType: String, Codable, Sendable {
    case checking, savings, investment, debt, deferredGrossCET
}

public enum FinancialDataSource: String, Codable, Sendable {
    case bank, manual
}

public struct FinancialAccountSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let ownerID: String
    public let type: FinancialAccountType
    public let source: FinancialDataSource
    public let balanceCents: Int64
    public let currency: String
    public let observedAt: Date

    public init(id: String, ownerID: String, type: FinancialAccountType, source: FinancialDataSource,
                balanceCents: Int64, currency: String = "EUR", observedAt: Date) {
        self.id = id
        self.ownerID = ownerID
        self.type = type
        self.source = source
        self.balanceCents = balanceCents
        self.currency = currency
        self.observedAt = observedAt
    }
}

public enum FinancialTransactionKind: String, Codable, Sendable {
    case expense, income, internalTransfer, other
}

public struct FinancialTransaction: Codable, Equatable, Sendable {
    public let accountID: String
    public let providerTransactionID: String
    /// Negative: outflow; positive: inflow. Refunds of purchases are positive expense entries.
    public let amountCents: Int64
    public let kind: FinancialTransactionKind
    public let booked: Bool

    public init(accountID: String, providerTransactionID: String, amountCents: Int64,
                kind: FinancialTransactionKind, booked: Bool) {
        self.accountID = accountID
        self.providerTransactionID = providerTransactionID
        self.amountCents = amountCents
        self.kind = kind
        self.booked = booked
    }
}

public struct FinancialGoalAllocation: Codable, Equatable, Sendable {
    public let goalID: String
    public let accountID: String
    public let reservedCents: Int64

    public init(goalID: String, accountID: String, reservedCents: Int64) {
        self.goalID = goalID
        self.accountID = accountID
        self.reservedCents = reservedCents
    }
}

public enum FinanceLedgerError: Error, Equatable {
    case duplicateAccount
    case duplicateTransactionConflict
    case invalidData
    case unsupportedCurrency
    case unknownAccount
    case insufficientFunds
    case amountOverflow
}

public struct FinanceLedgerSummary: Equatable, Sendable {
    /// Bank-sourced deposits only. This is not a promise of instant liquidity or a live balance.
    public let checkingCents: Int64
    public let savingsCents: Int64
    public let investmentsCents: Int64
    public let deferredCETGrossCents: Int64
    public let allocatedCents: Int64
    public let unallocatedDepositsCents: Int64
    public let netBookedExpensesCents: Int64
    public let pendingTransactionCount: Int
    /// Always label these accounts as out of date in the UI.
    public let staleAccountIDs: [String]
}

public enum FinanceLedger {
    /// Only pass accounts a member is authorized to see; the server must enforce authorization.
    /// Provider imports must classify internal transfers and card-settlement lines appropriately.
    public static func summarize(accounts: [FinancialAccountSnapshot],
                                 transactions: [FinancialTransaction],
                                 allocations: [FinancialGoalAllocation],
                                 now: Date,
                                 freshnessThreshold: TimeInterval = 24 * 3600,
                                 includeManualBalances: Bool = false) throws -> FinanceLedgerSummary {
        guard freshnessThreshold.isFinite, freshnessThreshold > 0, now.timeIntervalSince1970.isFinite else { throw FinanceLedgerError.invalidData }
        var accountsByID: [String: FinancialAccountSnapshot] = [:]
        var checking: Int64 = 0
        var savings: Int64 = 0
        var investments: Int64 = 0
        var cet: Int64 = 0
        var stale: [String] = []
        for account in accounts {
            guard !account.id.isEmpty, !account.ownerID.isEmpty, account.observedAt.timeIntervalSince1970.isFinite else { throw FinanceLedgerError.invalidData }
            guard account.currency == "EUR" else { throw FinanceLedgerError.unsupportedCurrency }
            guard accountsByID[account.id] == nil else { throw FinanceLedgerError.duplicateAccount }
            accountsByID[account.id] = account
            if account.source == .bank || (includeManualBalances && account.type != .deferredGrossCET) {
                if account.observedAt > now || now.timeIntervalSince(account.observedAt) > freshnessThreshold {
                    stale.append(account.id)
                }
                switch account.type {
                case .checking: checking = try add(checking, account.balanceCents)
                case .savings: savings = try add(savings, account.balanceCents)
                case .investment: investments = try add(investments, account.balanceCents)
                case .debt, .deferredGrossCET: break
                }
            } else if account.type == .deferredGrossCET {
                // Explicitly excluded from available money: gross, conditional and deferred.
                cet = try add(cet, account.balanceCents)
            }
        }
        var reservedByAccount: [String: Int64] = [:]
        var allocated: Int64 = 0
        for a in allocations {
            guard a.reservedCents >= 0, !a.goalID.isEmpty,
                  let account = accountsByID[a.accountID] else { throw FinanceLedgerError.unknownAccount }
            guard (account.source == .bank || includeManualBalances), account.type == .checking || account.type == .savings else {
                throw FinanceLedgerError.invalidData
            }
            reservedByAccount[a.accountID] = try add(reservedByAccount[a.accountID] ?? 0, a.reservedCents)
            allocated = try add(allocated, a.reservedCents)
        }
        for (id, amount) in reservedByAccount {
            guard let account = accountsByID[id], amount <= max(account.balanceCents, 0) else {
                throw FinanceLedgerError.insufficientFunds
            }
        }
        var seen: [TransactionKey: FinancialTransaction] = [:]
        var bookedExpenses: Int64 = 0
        var pendingCount = 0
        for transaction in transactions {
            guard accountsByID[transaction.accountID] != nil,
                  !transaction.providerTransactionID.isEmpty else { throw FinanceLedgerError.unknownAccount }
            let key = TransactionKey(account: transaction.accountID, id: transaction.providerTransactionID)
            if let previous = seen[key] {
                guard previous == transaction else { throw FinanceLedgerError.duplicateTransactionConflict }
                continue
            }
            seen[key] = transaction
            if !transaction.booked { pendingCount += 1; continue }
            if transaction.kind == .expense {
                let (newValue, overflow) = bookedExpenses.subtractingReportingOverflow(transaction.amountCents)
                guard !overflow else { throw FinanceLedgerError.amountOverflow }
                bookedExpenses = newValue
            }
        }
        let deposits = try add(checking, savings)
        let (unallocated, underflow) = deposits.subtractingReportingOverflow(allocated)
        guard !underflow else { throw FinanceLedgerError.amountOverflow }
        return FinanceLedgerSummary(checkingCents: checking,
                                    savingsCents: savings,
                                    investmentsCents: investments,
                                    deferredCETGrossCents: cet,
                                    allocatedCents: allocated,
                                    unallocatedDepositsCents: unallocated,
                                    netBookedExpensesCents: bookedExpenses,
                                    pendingTransactionCount: pendingCount,
                                    staleAccountIDs: stale.sorted())
    }

    private struct TransactionKey: Hashable {
        let account: String
        let id: String
    }

    private static func add(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else { throw FinanceLedgerError.amountOverflow }
        return result
    }
}
