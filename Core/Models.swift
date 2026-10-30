import Foundation

public enum DuoError: Error, LocalizedError {
    case invalid(String), conflict, unauthorized, unsupportedSchema
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return reason
        case .conflict: return "Une autre modification existe. Choisissez la version à conserver."
        case .unauthorized: return "Reconnectez-vous à votre compte."
        case .unsupportedSchema: return "Version de données non compatible. Mise à jour nécessaire ; vos données sont conservées."
        }
    }
}
public func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
}
public enum FoodUnit: String, Codable, CaseIterable, Sendable {
    case g, kg, ml, l, piece
    public var label: String { self == .piece ? "pièce(s)" : rawValue }
    public var dimension: String { switch self { case .g, .kg: return "mass"; case .ml, .l: return "volume"; case .piece: return "count" } }
    public var factor: Double { self == .kg || self == .l ? 1000 : 1 }
    public var base: FoodUnit { switch self { case .kg: return .g; case .l: return .ml; default: return self } }
    public func convert(_ quantity: Double, to target: FoodUnit) throws -> Double {
        guard quantity.isFinite, quantity >= 0, dimension == target.dimension else { throw DuoError.invalid("Quantité ou unités incompatibles.") }
        return quantity * factor / target.factor
    }
}
public struct Food: Codable, Equatable, Sendable {
    public var name: String; public var quantity: Double; public var unit: FoodUnit
    public var category: String; public var location: String; public var expiry: Date?; public var added: Date
    public init(name: String, quantity: Double, unit: FoodUnit, category: String = "Autres", location: String = "Frigo", expiry: Date? = nil, added: Date = Date()) {
        self.name = name; self.quantity = quantity; self.unit = unit; self.category = category; self.location = location; self.expiry = expiry; self.added = added
    }
    public func validate() throws {
        guard !normalized(name).isEmpty, name.count <= 100, quantity.isFinite, quantity >= 0, quantity <= 1_000_000 else { throw DuoError.invalid("Saisissez un nom et une quantité entre 0 et 1 000 000.") }
        if unit == .piece && quantity.rounded() != quantity { throw DuoError.invalid("Utilisez un nombre entier de pièces.") }
    }
}
public struct Ingredient: Codable, Equatable, Sendable {
    public var name: String; public var quantity: Double; public var unit: FoodUnit
    public init(_ name: String, _ quantity: Double, _ unit: FoodUnit) { self.name = name; self.quantity = quantity; self.unit = unit }
    public var key: String { normalized(name) + "|" + unit.dimension }
}
public struct Recipe: Codable, Identifiable, Equatable, Sendable {
    public var id: String; public var title: String; public var portions: Int; public var preparation: Int; public var cooking: Int
    public var ingredients: [Ingredient]; public var steps: [String]; public var allergens: [String]; public var family: String
}
public struct Meal: Codable, Equatable, Sendable {
    public var recipeID: String; public var date: Date; public var portions: Int; public var cooked: Bool = false
    public init(recipeID: String, date: Date, portions: Int = 2) { self.recipeID = recipeID; self.date = date; self.portions = portions }
}
public struct Shopping: Codable, Equatable, Sendable {
    public var ingredient: Ingredient; public var checked: Bool = false; public var generated: Bool = false; public var category: String = "Alimentation"
    public init(ingredient: Ingredient, generated: Bool = false) { self.ingredient = ingredient; self.generated = generated }
}
public struct HouseTask: Codable, Equatable, Sendable {
    public var title: String; public var assignee: String; public var due: Date?; public var repeatDays: Int; public var completed: Date?
    public init(title: String, assignee: String = "Ensemble", due: Date? = nil, repeatDays: Int = 0) { self.title = title; self.assignee = assignee; self.due = due; self.repeatDays = repeatDays }
}
public struct Event: Codable, Equatable, Sendable {
    public var title: String; public var start: Date; public var end: Date; public var timeZone: String; public var sport: Bool
    public init(title: String, start: Date, end: Date, sport: Bool = false, timeZone: String = TimeZone.current.identifier) { self.title = title; self.start = start; self.end = end; self.sport = sport; self.timeZone = timeZone }
    public func overlaps(_ other: Event) -> Bool { start < other.end && end > other.start }
}
public struct Habit: Codable, Equatable, Sendable {
    public var title: String; public var weeklyGoal: Int; public var completions: [Date]
    public init(title: String, weeklyGoal: Int = 3) { self.title = title; self.weeklyGoal = weeklyGoal; self.completions = [] }
    public func progress(at now: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return Set(completions.filter { interval.contains($0) }.map { calendar.startOfDay(for: $0) }).count
    }
}
public enum Content: Codable, Equatable, Sendable {
    case food(Food), shopping(Shopping), meal(Meal), task(HouseTask), event(Event), habit(Habit)
    public var kind: String { switch self { case .food: return "food"; case .shopping: return "shopping"; case .meal: return "meal"; case .task: return "task"; case .event: return "event"; case .habit: return "habit" } }
    public func validate() throws {
        switch self {
        case .food(let f): try f.validate()
        case .shopping(let s): try Food(name: s.ingredient.name, quantity: s.ingredient.quantity, unit: s.ingredient.unit).validate()
        case .meal(let m): guard (1...12).contains(m.portions), !m.recipeID.isEmpty else { throw DuoError.invalid("Portions invalides.") }
        case .task(let t): guard !normalized(t.title).isEmpty, t.title.count <= 200, (0...365).contains(t.repeatDays) else { throw DuoError.invalid("Tâche ou récurrence invalide.") }
        case .event(let e): guard !normalized(e.title).isEmpty, e.title.count <= 200, !normalized(e.timeZone).isEmpty, e.end > e.start else { throw DuoError.invalid("La fin doit suivre le début.") }
        case .habit(let h): guard !normalized(h.title).isEmpty, h.title.count <= 200, (1...7).contains(h.weeklyGoal) else { throw DuoError.invalid("Objectif entre 1 et 7 jours.") }
        }
    }
}
public struct Record: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID; public var householdID: UUID; public var ownerID: UUID?; public var createdBy: UUID?; public var revision: Int; public var deleted: Bool; public var payload: Content
    public init(id: UUID = UUID(), householdID: UUID, ownerID: UUID? = nil, createdBy: UUID? = nil, payload: Content) { self.id = id; self.householdID = householdID; self.ownerID = ownerID; self.createdBy = createdBy; self.revision = 0; self.deleted = false; self.payload = payload }
    enum CodingKeys: String, CodingKey { case id, householdID = "household_id", ownerID = "owner_id", createdBy = "created_by", revision, deleted, payload }
}
public struct Conflict: Codable, Identifiable, Sendable { public var id: UUID { local.id }; public var local: Record; public var remote: Record }
public struct Snapshot: Codable, Sendable {
    public var schema = 1; public var householdID: UUID; public var userID: UUID; public var records: [Record] = []; public var pending: [UUID] = []; public var conflicts: [Conflict] = []
    public init(householdID: UUID = UUID(), userID: UUID = UUID()) { self.householdID = householdID; self.userID = userID }
    public static func decode(_ data: Data) throws -> Snapshot {
        let s = try JSONDecoder().decode(Snapshot.self, from: data)
        guard s.schema == 1 else { throw DuoError.unsupportedSchema }
        let ids = Set(s.records.map(\.id))
        guard ids.count == s.records.count, s.pending.allSatisfy({ ids.contains($0) }) else { throw DuoError.invalid("Index local incohérent. Les données sont conservées.") }
        for row in s.records {
            guard row.householdID == s.householdID, row.ownerID == nil || row.ownerID == s.userID, row.revision >= 0 else { throw DuoError.unauthorized }
            try row.payload.validate()
        }
        return s
    }
    public mutating func put(_ row: Record) throws {
        try row.payload.validate()
        guard row.householdID == householdID, row.ownerID == nil || row.ownerID == userID else { throw DuoError.unauthorized }
        if let i = records.firstIndex(where: { $0.id == row.id }) { records[i] = row } else { records.append(row) }
        if !pending.contains(row.id) { pending.append(row.id) }
    }
    public mutating func receive(_ remote: Record) {
        // An invalid or stale server response must never overwrite a valid offline cache.
        guard remote.householdID == householdID, remote.ownerID == nil || remote.ownerID == userID,
              remote.revision >= 0, (try? remote.payload.validate()) != nil else { return }
        if let i = records.firstIndex(where: { $0.id == remote.id }) {
            guard remote.revision >= records[i].revision else { return }
            if pending.contains(remote.id) {
                if remote.revision > records[i].revision && !conflicts.contains(where: { $0.id == remote.id }) { conflicts.append(Conflict(local: records[i], remote: remote)) }
            } else { records[i] = remote }
        } else { records.append(remote) }
    }
}
