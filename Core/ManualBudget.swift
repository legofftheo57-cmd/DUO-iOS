import Foundation

public enum BudgetKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case income = "Revenu", expense = "Dépense", savings = "Épargne"
    public var id: String { rawValue }
}
public struct BudgetEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: BudgetKind
    public var cents: Int
    public var title: String
    public var person: String
    public var shared: Bool
    public init(id: UUID = UUID(), date: Date, kind: BudgetKind, cents: Int, title: String, person: String, shared: Bool = false) {
        self.id = id; self.date = date; self.kind = kind; self.cents = cents
        self.title = title; self.person = person; self.shared = shared
    }
}
public enum ManualBudget {
    public static func validate(_ entries: [BudgetEntry]) throws {
        guard entries.count <= 10_000, Set(entries.map(\.id)).count == entries.count else { throw DuoError.invalid("Budget trop volumineux ou opérations dupliquées.") }
        for entry in entries {
            guard (1...100_000_000).contains(entry.cents), !normalized(entry.title).isEmpty,
                  entry.title.count <= 200, ["Théo", "Lilou"].contains(entry.person),
                  !entry.shared || entry.kind == .expense, entry.date.timeIntervalSince1970.isFinite else {
                throw DuoError.invalid("Opération budgétaire invalide. Les données précédentes sont conservées.")
            }
        }
    }
    public static func amountInCents(_ input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }), let whole = Int(parts[0]), whole <= 1_000_000 else { return nil }
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.count <= 2, parts.count == 1 || !fraction.isEmpty,
              fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let value = whole * 100 + (Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
        return (1...100_000_000).contains(value) ? value : nil
    }
}

public struct ManualFinancialAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var type: FinancialAccountType
    public var cents: Int64
    public var observedAt: Date
    public init(id: UUID = UUID(), name: String, type: FinancialAccountType, cents: Int64, observedAt: Date) {
        self.id = id; self.name = name; self.type = type; self.cents = cents; self.observedAt = observedAt
    }
    public func ledgerSnapshot(owner: UUID) -> FinancialAccountSnapshot {
        .init(id: id.uuidString, ownerID: owner.uuidString, type: type, source: .manual, balanceCents: cents, observedAt: observedAt)
    }
    public static func validate(_ accounts: [ManualFinancialAccount]) throws {
        guard accounts.count <= 100, Set(accounts.map(\.id)).count == accounts.count else { throw DuoError.invalid("Comptes trop nombreux ou dupliqués.") }
        for account in accounts {
            guard !normalized(account.name).isEmpty, account.name.count <= 100,
                  (-100_000_000...100_000_000).contains(account.cents),
                  account.type == .checking || account.cents >= 0,
                  account.observedAt.timeIntervalSince1970.isFinite else { throw DuoError.invalid("Solde manuel invalide.") }
        }
    }
}
