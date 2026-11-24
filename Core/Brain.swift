import Foundation

// MARK: - Le cerveau de DUO
// Tout est calculé sur l'iPhone, sans réseau et sans coût.
// Les règles sont déterministes et testables ; l'IA d'Apple (si disponible)
// ne fait que reformuler et compléter ces propositions côté application.

public enum DuoPerson: String, Codable, CaseIterable, Sendable {
    case theo = "Théo", lilou = "Lilou"
    public var initial: String { String(rawValue.prefix(1)) }
    public var other: DuoPerson { self == .theo ? .lilou : .theo }
}

/// Plage de travail en minutes depuis minuit.
public struct WorkSlot: Equatable, Sendable {
    public var start: Int; public var end: Int; public var label: String
    public init(start: Int, end: Int, label: String) { self.start = start; self.end = end; self.label = label }
}

/// Horaires du couple : 2×8 de Théo (alternance hebdomadaire) et horaires fixes de Lilou.
public enum DuoSchedule {
    /// Lundi 16 novembre 2026 : semaine du soir pour Théo.
    public static let eveningAnchor: DateComponents = DateComponents(year: 2026, month: 11, day: 16)

    public static func isMorningWeek(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let anchor = calendar.date(from: eveningAnchor) else { return true }
        let monday = startOfWeek(date, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: monday).day ?? 0
        let weeks = Int((Double(days) / 7).rounded(.down))
        return ((weeks % 2) + 2) % 2 == 1
    }
    public static func startOfWeek(_ date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar; cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
    /// Jour ISO : 1 = lundi … 7 = dimanche.
    public static func isoWeekday(_ date: Date, calendar: Calendar = .current) -> Int {
        let w = calendar.component(.weekday, from: date); return w == 1 ? 7 : w - 1
    }
    public static func work(_ person: DuoPerson, on date: Date, calendar: Calendar = .current) -> WorkSlot? {
        let day = isoWeekday(date, calendar: calendar)
        guard day <= 5 else { return nil }
        switch person {
        case .theo:
            return isMorningWeek(date, calendar: calendar)
                ? WorkSlot(start: 5 * 60 + 28, end: 13 * 60, label: "Usine · matin")
                : WorkSlot(start: 13 * 60, end: 20 * 60 + 32, label: "Usine · soir")
        case .lilou:
            return WorkSlot(start: 8 * 60, end: day == 5 ? 16 * 60 : 17 * 60, label: "Travail")
        }
    }
    /// Minute à partir de laquelle la personne est disponible à la maison (trajet inclus).
    public static func freeFrom(_ person: DuoPerson, on date: Date, calendar: Calendar = .current) -> Int {
        guard let slot = work(person, on: date, calendar: calendar) else { return 9 * 60 }
        return slot.end + 30
    }
    /// Énergie estimée de 0 (épuisé) à 3 (en forme), selon les horaires et le journal.
    public static func energy(_ person: DuoPerson, on date: Date, tiredDays: [Int] = [], calendar: Calendar = .current) -> Int {
        var e = 3
        if let slot = work(person, on: date, calendar: calendar) {
            e -= 1
            if person == .theo && slot.start < 6 * 60 { e -= 1 }            // lever à 4 h 40
            if person == .theo && slot.end > 20 * 60 { e -= 1 }             // rentre après 21 h
        }
        if tiredDays.contains(isoWeekday(date, calendar: calendar)) { e -= 1 }
        return max(0, min(3, e))
    }
    /// Qui est le mieux placé pour cuisiner ce soir.
    public static func cook(on date: Date, calendar: Calendar = .current) -> DuoPerson? {
        let t = freeFrom(.theo, on: date, calendar: calendar), l = freeFrom(.lilou, on: date, calendar: calendar)
        if work(.theo, on: date, calendar: calendar) == nil && work(.lilou, on: date, calendar: calendar) == nil { return nil }
        if t > 19 * 60 { return .lilou }
        return t <= l ? .theo : .lilou
    }
}

// MARK: - Journal des habitudes (local, jamais envoyé)

public enum JournalKind: String, Codable, Sendable {
    case taskDone, mealCooked, leftover, tired, bought, accepted, declined
}
public struct JournalEntry: Codable, Equatable, Sendable {
    public var kind: JournalKind; public var title: String; public var person: String; public var date: Date; public var ref: String?
    public init(kind: JournalKind, title: String, person: String, date: Date = Date(), ref: String? = nil) {
        self.kind = kind; self.title = String(title.prefix(120)); self.person = person; self.date = date; self.ref = ref
    }
}

// MARK: - Propositions

public enum ProposalAction: Equatable, Sendable {
    case moveTask(id: UUID, to: Date)
    case eatLeftovers(food: String)
    case addShopping(name: String, quantity: Double, unit: FoodUnit)
    case planRecipe(id: String, on: Date)
    case planWeek
    case none
}
public struct Proposal: Identifiable, Equatable, Sendable {
    /// Clé stable : une proposition refusée ne revient pas le même jour.
    public var id: String; public var family: String; public var title: String; public var detail: String
    public var accept: String; public var action: ProposalAction; public var tint: Int
    public init(id: String, family: String, title: String, detail: String, accept: String = "Oui", action: ProposalAction, tint: Int = 0) {
        self.id = id; self.family = family; self.title = title; self.detail = detail; self.accept = accept; self.action = action; self.tint = tint
    }
}

/// Une tâche telle que le cerveau la voit.
public struct BrainTask: Sendable {
    public var id: UUID; public var title: String; public var person: DuoPerson?; public var due: Date?; public var repeatDays: Int; public var done: Bool
    public init(id: UUID, title: String, person: DuoPerson?, due: Date?, repeatDays: Int, done: Bool) {
        self.id = id; self.title = title; self.person = person; self.due = due; self.repeatDays = repeatDays; self.done = done
    }
}

public enum Brain {
    public static let leftoverCategory = "Restes"

    // MARK: Habitudes
    /// Jours (1…7) où « crevé » a été signalé au moins 2 fois sur 6 semaines.
    public static func tiredDays(_ journal: [JournalEntry], person: String, now: Date, calendar: Calendar = .current) -> [Int] {
        let since = now.addingTimeInterval(-42 * 86400)
        var count: [Int: Int] = [:]
        for e in journal where e.kind == .tired && e.person == person && e.date > since { count[DuoSchedule.isoWeekday(e.date, calendar: calendar), default: 0] += 1 }
        return count.filter { $0.value >= 2 }.map(\.key).sorted()
    }
    /// Intervalle réel moyen (en jours) entre deux réalisations d'une même tâche.
    public static func realInterval(_ title: String, journal: [JournalEntry]) -> Int? {
        let dates = journal.filter { $0.kind == .taskDone && normalized($0.title) == normalized(title) }.map(\.date).sorted()
        guard dates.count >= 3 else { return nil }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) / 86400 }
        return Int((gaps.reduce(0, +) / Double(gaps.count)).rounded())
    }
    /// Nombre de jours moyen entre deux achats d'un même produit.
    public static func restockInterval(_ name: String, journal: [JournalEntry]) -> Int? {
        let dates = journal.filter { $0.kind == .bought && normalized($0.title) == normalized(name) }.map(\.date).sorted()
        guard dates.count >= 3 else { return nil }
        let gaps = zip(dates.dropFirst(), dates).map { $0.timeIntervalSince($1) / 86400 }
        return max(1, Int((gaps.reduce(0, +) / Double(gaps.count)).rounded()))
    }
    /// Part des tâches faites par Théo sur 7 jours (0…100), 50 si aucune donnée.
    public static func balance(_ journal: [JournalEntry], now: Date) -> Int {
        let week = journal.filter { $0.kind == .taskDone && $0.date > now.addingTimeInterval(-7 * 86400) }
        let t = week.filter { $0.person == DuoPerson.theo.rawValue }.count, l = week.filter { $0.person == DuoPerson.lilou.rawValue }.count
        return t + l == 0 ? 50 : Int((Double(t) * 100 / Double(t + l)).rounded())
    }
    /// Une famille refusée 3 fois en 14 jours sans acceptation se met en sourdine.
    public static func muted(_ journal: [JournalEntry], now: Date) -> Set<String> {
        let recent = journal.filter { $0.date > now.addingTimeInterval(-14 * 86400) }
        var declined: [String: Int] = [:], accepted: Set<String> = []
        for e in recent { if e.kind == .declined, let f = e.ref { declined[f, default: 0] += 1 }; if e.kind == .accepted, let f = e.ref { accepted.insert(f) } }
        return Set(declined.filter { $0.value >= 3 && !accepted.contains($0.key) }.map(\.key))
    }

    // MARK: Propositions du jour
    public static func proposals(now: Date, me: DuoPerson, foods: [Food], meals: [Meal], tasks: [BrainTask], shopping: [String],
                                 journal: [JournalEntry], dismissedToday: Set<String>, calendar: Calendar = .current) -> [Proposal] {
        var out: [Proposal] = []
        let today = calendar.startOfDay(for: now)
        let dayKey = CoupleSchedule.dayKey(now, calendar: calendar)
        let tired = tiredDays(journal, person: me.rawValue, now: now, calendar: calendar)
        let mutedFamilies = muted(journal, now: now)
        let tonight = meals.first { calendar.isDate($0.date, inSameDayAs: now) && !$0.cooked }

        // 1. Restes à finir avant tout autre repas.
        if let rest = foods.first(where: { $0.category == leftoverCategory && ($0.expiry ?? .distantFuture) >= today }) {
            let name = rest.name.replacingOccurrences(of: "Restes : ", with: "")
            out.append(Proposal(id: "leftover-\(dayKey)-\(normalized(name))", family: "leftover",
                                title: "Ce soir, les restes de \(name.lowercased())",
                                detail: tonight == nil ? "\(Int(rest.quantity)) part(s) au frigo : rien à cuisiner." : "Le repas prévu glisse à demain, rien n'est gaspillé.",
                                accept: "On mange les restes", action: .eatLeftovers(food: rest.name), tint: 1))
        }
        // 2. Produits qui périment bientôt.
        let soon = foods.filter { f in
            guard f.category != leftoverCategory, let e = f.expiry else { return false }
            return e >= today && e < today.addingTimeInterval(3 * 86400)
        }
        if !soon.isEmpty {
            let names = soon.prefix(2).map { $0.name.lowercased() }
            let plannedIDs = Set(meals.filter { $0.date >= today && !$0.cooked }.map(\.recipeID))
            let uses = Catalog.recipes.filter { r in !plannedIDs.contains(r.id) && r.ingredients.contains { ing in soon.contains { normalized($0.name).contains(normalized(ing.name)) || normalized(ing.name).contains(normalized($0.name)) } } }
            let alreadyUsed = Catalog.recipes.filter { plannedIDs.contains($0.id) }.contains { r in r.ingredients.contains { ing in soon.contains { normalized($0.name).contains(normalized(ing.name)) } } }
            if !alreadyUsed, let r = uses.min(by: { (Catalog.cost[$0.id] ?? 9) < (Catalog.cost[$1.id] ?? 9) }) {
                let day = tonight == nil ? today : today.addingTimeInterval(86400)
                out.append(Proposal(id: "expiry-\(dayKey)-\(r.id)", family: "expiry",
                                    title: "\(names.joined(separator: " et ").capitalizedFirst) à finir vite",
                                    detail: "\(r.title) \(tonight == nil ? "ce soir" : "demain") les utilise, environ \(euros(Catalog.cost[r.id] ?? 4)).",
                                    accept: "Au menu", action: .planRecipe(id: r.id, on: day), tint: 2))
            }
        }
        // 3. Rien de prévu ce soir.
        if tonight == nil && !out.contains(where: { $0.family == "leftover" }) {
            let recent = Set(meals.filter { $0.date > now.addingTimeInterval(-6 * 86400) }.map(\.recipeID))
            let quick = DuoSchedule.energy(DuoSchedule.cook(on: now, calendar: calendar) ?? me, on: now, tiredDays: tired, calendar: calendar) <= 1
            let pool = Catalog.recipes.filter { !recent.contains($0.id) && (!quick || $0.preparation + $0.cooking <= 30) }
            let scored = pool.sorted { a, b in
                let sa = MealEngine.missing(a.ingredients, stock: foods).count, sb = MealEngine.missing(b.ingredients, stock: foods).count
                return sa != sb ? sa < sb : (Catalog.cost[a.id] ?? 9) < (Catalog.cost[b.id] ?? 9)
            }
            if let r = scored.first {
                let who = DuoSchedule.cook(on: now, calendar: calendar)
                out.append(Proposal(id: "tonight-\(dayKey)-\(r.id)", family: "tonight",
                                    title: "Rien de prévu ce soir : \(r.title.lowercased()) ?",
                                    detail: "\(r.preparation + r.cooking) min · ~\(euros(Catalog.cost[r.id] ?? 4))\(who.map { " · \($0.rawValue) est libre plus tôt" } ?? "")\(quick ? " · version rapide, la journée est chargée" : "").",
                                    accept: "Au menu", action: .planRecipe(id: r.id, on: today), tint: 2))
            }
        }
        // 4. Journée chargée : déplacer une tâche lourde de « moi ».
        let myEnergy = DuoSchedule.energy(me, on: now, tiredDays: tired, calendar: calendar)
        if myEnergy <= 1, let heavy = tasks.first(where: { t in
            !t.done && t.person == me && t.repeatDays != 1 && (t.due.map { calendar.isDate($0, inSameDayAs: now) } ?? false)
        }) {
            let target = nextLightDay(for: me, after: now, tiredDays: tired, calendar: calendar)
            out.append(Proposal(id: "move-\(dayKey)-\(heavy.id.uuidString)", family: "energy",
                                title: "Grosse journée : « \(heavy.title) » plus tard ?",
                                detail: "Je la place \(weekdayName(target, calendar: calendar)), un jour plus léger pour toi.",
                                accept: "Déplacer", action: .moveTask(id: heavy.id, to: target), tint: 0))
        }
        // 5. Équilibre des tâches.
        let b = balance(journal, now: now)
        if (b >= 65 || b <= 35), let t = tasks.first(where: { !$0.done && $0.person == (b >= 65 ? .theo : .lilou) && $0.repeatDays != 1 }) {
            let light = b >= 65 ? DuoPerson.lilou : .theo
            out.append(Proposal(id: "balance-\(dayKey)-\(t.id.uuidString)", family: "balance",
                                title: "\(b >= 65 ? "Théo" : "Lilou") a fait \(b >= 65 ? b : 100 - b) % des tâches cette semaine",
                                detail: "« \(t.title) » pourrait revenir à \(light.rawValue) cette fois-ci.", accept: "Proposer", action: .none, tint: 3))
        }
        // 6. Produits de base qui reviennent.
        let shoppingSet = Set(shopping.map(normalized))
        for staple in ["lait", "œufs", "pain", "pâtes", "papier toilette"] where !shoppingSet.contains(normalized(staple)) {
            guard let every = restockInterval(staple, journal: journal),
                  let last = journal.filter({ $0.kind == .bought && normalized($0.title) == normalized(staple) }).map(\.date).max(),
                  now.timeIntervalSince(last) / 86400 >= Double(every) - 1 else { continue }
            out.append(Proposal(id: "restock-\(dayKey)-\(normalized(staple))", family: "restock",
                                title: "\(staple.capitalizedFirst) : bientôt fini", detail: "Vous en rachetez environ tous les \(every) jours.",
                                accept: "Ajouter aux courses", action: .addShopping(name: staple.capitalizedFirst, quantity: 1, unit: .piece), tint: 2))
            break
        }
        // 7. Semaine sans menu.
        let weekMeals = meals.filter { $0.date >= today && $0.date < today.addingTimeInterval(7 * 86400) }
        if (weekMeals.count < 3 && calendar.component(.weekday, from: now) == 1) || weekMeals.isEmpty {
            out.append(Proposal(id: "week-\(dayKey)", family: "week", title: "Je prépare vos repas de la semaine ?",
                                detail: "Frigo d'abord, petit budget, plats rapides les jours chargés.", accept: "Préparer", action: .planWeek, tint: 1))
        }
        return out.filter { !dismissedToday.contains($0.id) && !mutedFamilies.contains($0.family) }
    }

    public static func nextLightDay(for person: DuoPerson, after date: Date, tiredDays: [Int], calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        for i in 1...7 {
            let d = start.addingTimeInterval(Double(i) * 86400)
            if DuoSchedule.energy(person, on: d, tiredDays: tiredDays, calendar: calendar) >= 2 { return d.addingTimeInterval(10 * 3600) }
        }
        return start.addingTimeInterval(2 * 86400 + 10 * 3600)
    }
    public static func weekdayName(_ date: Date, calendar: Calendar = .current) -> String {
        ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"][DuoSchedule.isoWeekday(date, calendar: calendar) - 1]
    }
    public static func euros(_ v: Double) -> String { String(format: "%.2f €", v).replacingOccurrences(of: ".", with: ",") }

    /// Coût estimé d'une liste de repas (catalogue), en euros.
    public static func weekCost(_ meals: [Meal]) -> Double {
        meals.reduce(0) { $0 + (Catalog.cost[$1.recipeID] ?? 4) * Double($1.portions) / 2 }
    }
    /// Pièce de la maison déduite du titre d'une tâche.
    public static func room(for title: String) -> Int {
        let t = normalized(title)
        let map: [(Int, [String])] = [(0, ["vaisselle", "cuisine", "frigo", "four", "plan de travail", "poubelle", "micro"]),
                                      (2, ["draps", "lit", "chambre", "linge", "repassage", "armoire"]),
                                      (3, ["salle de bain", "lavabo", "douche", "wc", "toilette", "baignoire", "miroir"])]
        for (room, keys) in map where keys.contains(where: { t.contains($0) }) { return room }
        return 1
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
