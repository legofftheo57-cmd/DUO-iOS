import SwiftUI
import DUOCore

/// Branche le cerveau (DUOCore.Brain) sur les données de l'app.
extension AppStore {
    var me: DuoPerson { DuoPerson(rawValue: UserDefaults.standard.string(forKey: "duo.me") ?? DuoPerson.theo.rawValue) ?? .theo }

    var taskRows: [(Record, HouseTask)] { records.compactMap { r in if case .task(let t) = r.payload { return (r, t) }; return nil } }
    var mealRows: [(Record, Meal)] { records.compactMap { r in if case .meal(let m) = r.payload { return (r, m) }; return nil }.sorted { $0.1.date < $1.1.date } }
    var foodRows: [(Record, Food)] { records.compactMap { r in if case .food(let f) = r.payload { return (r, f) }; return nil } }
    var shoppingRows: [(Record, Shopping)] { records.compactMap { r in if case .shopping(let s) = r.payload { return (r, s) }; return nil } }

    /// Traduit le champ « assignee » (identifiants) en personne du couple, sur n'importe quel téléphone.
    func person(forAssignee value: String) -> DuoPerson? {
        let mine = snapshot.userID.uuidString
        if value == mine { return me }
        if value == "partner-of:" + mine { return me.other }
        if value.hasPrefix("partner-of:") { return me }
        if UUID(uuidString: value) != nil { return me.other }
        return nil
    }
    func assignee(for person: DuoPerson?) -> String {
        guard let person else { return "Ensemble" }
        return person == me ? snapshot.userID.uuidString : "partner-of:" + snapshot.userID.uuidString
    }

    var openTasks: [(Record, HouseTask)] {
        taskRows.filter { $0.1.completed == nil }.sorted { ($0.1.due ?? .distantFuture) < ($1.1.due ?? .distantFuture) }
    }
    func meal(on day: Date) -> (Record, Meal)? { mealRows.first { Calendar.current.isDate($0.1.date, inSameDayAs: day) } }
    func recipe(_ id: String) -> Recipe? { Catalog.recipes.first { $0.id == id } }
    var leftovers: [(Record, Food)] { foodRows.filter { $0.1.category == Brain.leftoverCategory } }

    // MARK: Journal
    func log(_ kind: JournalKind, _ title: String, person: DuoPerson? = nil, ref: String? = nil) {
        transact { s in
            var j = s.journal ?? []
            j.append(JournalEntry(kind: kind, title: title, person: (person ?? me).rawValue, ref: ref))
            s.journal = Array(j.suffix(800))
        }
    }

    // MARK: Propositions
    var proposals: [Proposal] {
        Brain.proposals(now: Date(), me: me, foods: foods, meals: meals,
                        tasks: taskRows.map { BrainTask(id: $0.0.id, title: $0.1.title, person: person(forAssignee: $0.1.assignee), due: $0.1.due, repeatDays: $0.1.repeatDays, done: $0.1.completed != nil) },
                        shopping: shoppingRows.filter { !$0.1.checked }.map(\.1.ingredient.name),
                        journal: snapshot.journal ?? [], dismissedToday: Set(snapshot.dismissed ?? []))
    }
    func dismiss(_ p: Proposal) {
        transact { s in var d = s.dismissed ?? []; d.append(p.id); s.dismissed = Array(d.suffix(300)) }
        log(.declined, p.title, ref: p.family)
    }
    func accept(_ p: Proposal) {
        switch p.action {
        case .moveTask(let id, let date):
            if let found = taskRows.first(where: { $0.0.id == id }) { var t = found.1; t.due = date; put(.task(t), editing: found.0) }
        case .eatLeftovers(let name):
            if let tonight = meal(on: Date()), !tonight.1.cooked {
                var m = tonight.1; m.date = m.date.addingTimeInterval(86400); put(.meal(m), editing: tonight.0)
            }
            if let rest = leftovers.first(where: { $0.1.name == name }) { remove(rest.0) }
        case .addShopping(let name, let q, let unit):
            put(.shopping(Shopping(ingredient: Ingredient(name, q, unit))))
        case .planRecipe(let id, let day):
            let at = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: day) ?? day
            if let existing = meal(on: day), !existing.1.cooked { var m = existing.1; m.recipeID = id; put(.meal(m), editing: existing.0) }
            else { put(.meal(Meal(recipeID: id, date: at))) }
        case .planWeek:
            planWeek()
        case .none: break
        }
        transact { s in var d = s.dismissed ?? []; d.append(p.id); s.dismissed = Array(d.suffix(300)) }
        log(.accepted, p.title, ref: p.family)
        if error == nil { toast = "C'est fait" }
    }

    /// Menus des 7 prochains jours : frigo d'abord, budget bas, plats rapides les jours chargés.
    func planWeek() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let free = (0..<7).map { start.addingTimeInterval(Double($0) * 86400) }.filter { meal(on: $0) == nil }
        guard !free.isEmpty else { toast = "La semaine est déjà prévue"; return }
        var used = Set(meals.filter { $0.date > Date().addingTimeInterval(-6 * 86400) }.map(\.recipeID))
        transact { s in
            for day in free {
                let busy = DuoSchedule.energy(DuoSchedule.cook(on: day) ?? self.me, on: day) <= 1
                let excluded = self.exclusions
                let pool = Catalog.recipes.filter { r in
                    let allergens = Set(r.allergens.map { normalized($0) })
                    return !used.contains(r.id) && allergens.isDisjoint(with: excluded) && (!busy || r.preparation + r.cooking <= 30)
                }
                let pick = pool.min { a, b in
                    let ma = MealEngine.missing(a.ingredients, stock: self.foods).count, mb = MealEngine.missing(b.ingredients, stock: self.foods).count
                    return ma != mb ? ma < mb : (Catalog.cost[a.id] ?? 9) < (Catalog.cost[b.id] ?? 9)
                }
                guard let r = pick else { continue }
                used.insert(r.id)
                let at = cal.date(bySettingHour: 19, minute: 30, second: 0, of: day) ?? day
                try s.put(Record(householdID: s.householdID, payload: .meal(Meal(recipeID: r.id, date: at))))
            }
            try self.rebuildShopping(&s)
        }
        if error == nil { toast = "\(free.count) repas prévus · courses mises à jour" }
    }

    // MARK: Actions avec mémoire
    func complete(_ row: Record) {
        guard case .task(let t) = row.payload else { return }
        let wasOpen = t.completed == nil
        if wasOpen { toggle(row) } else { reopenTask(row) }
        guard error == nil, wasOpen else { return }
        log(.taskDone, t.title, person: person(forAssignee: t.assignee) ?? me)
        if t.repeatDays == 1 { toast = "Fait · revient demain" }
        else if t.repeatDays > 1 {
            let next = Date().addingTimeInterval(Double(t.repeatDays) * 86400)
            toast = "Fait · revient dans \(t.repeatDays) j (\(next.formatted(.dateTime.day().month(.abbreviated))))"
        } else { toast = "Fait" }
    }
    func markCooked(_ row: Record) {
        guard case .meal(let m) = row.payload, !m.cooked else { return }
        cook(row)
        if error == nil { log(.mealCooked, recipe(m.recipeID)?.title ?? m.recipeID); toast = "Repas noté · frigo mis à jour" }
    }
    func addLeftover(from row: Record) {
        guard case .meal(let m) = row.payload, let r = recipe(m.recipeID) else { return }
        let name = "Restes : " + r.title
        if let existing = leftovers.first(where: { $0.1.name == name }) {
            var f = existing.1; f.quantity += 1; put(.food(f), editing: existing.0)
        } else {
            put(.food(Food(name: name, quantity: 1, unit: .piece, category: Brain.leftoverCategory, location: "Frigo",
                           expiry: Calendar.current.startOfDay(for: Date()).addingTimeInterval(3 * 86400))))
        }
        if error == nil { log(.leftover, r.title); toast = "Restes notés · prévus pour demain" }
    }
    func swapMeal(_ row: Record) {
        guard case .meal(var m) = row.payload else { return }
        let recent = Set(meals.map(\.recipeID))
        let options = suggestions.filter { !recent.contains($0.id) } + Catalog.recipes.filter { !recent.contains($0.id) }
        guard let next = options.first else { return }
        m.recipeID = next.id; put(.meal(m), editing: row)
    }
    func toggleShopping(_ row: Record) {
        guard case .shopping(let item) = row.payload else { return }
        toggle(row)
        if error == nil && !item.checked { log(.bought, item.ingredient.name) }
    }
    /// « Je suis crevé » : mes tâches du jour non urgentes glissent vers un jour plus léger.
    func imTired() {
        let tired = Brain.tiredDays(snapshot.journal ?? [], person: me.rawValue, now: Date())
        let target = Brain.nextLightDay(for: me, after: Date(), tiredDays: tired)
        var moved = 0
        for (row, task) in openTasks where person(forAssignee: task.assignee) == me && task.repeatDays != 1 {
            guard task.due.map({ $0 < Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400) }) ?? true else { continue }
            var t = task; t.due = target; put(.task(t), editing: row); moved += 1
        }
        log(.tired, "Journée chargée")
        toast = moved == 0 ? "Noté · repos ce soir" : "\(moved) tâche(s) déplacée(s) à \(Brain.weekdayName(target)) · repose-toi"
    }
    /// Pourcentage de tâches faites aujourd'hui (anneau de l'accueil).
    var todayProgress: Double {
        let cal = Calendar.current
        let today = taskRows.filter { r in (r.1.due.map { cal.isDateInToday($0) } ?? false) || (r.1.completed.map { cal.isDateInToday($0) } ?? false) }
        guard !today.isEmpty else { return 0 }
        return Double(today.filter { $0.1.completed != nil }.count) / Double(today.count)
    }
}
