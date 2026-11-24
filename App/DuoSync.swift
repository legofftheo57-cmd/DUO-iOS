import SwiftUI
import DUOCore

/// État de la connexion entre les deux téléphones, tel qu'il est montré à l'écran.
enum LinkState: Equatable {
    case noServer          // app compilée sans serveur : un seul téléphone
    case signedOut         // pas encore de compte sur ce téléphone
    case noHome            // compte ouvert, foyer pas encore créé ou rejoint
    case linked            // dans le foyer : tout est partagé
}

extension AppStore {
    var linkState: LinkState {
        if DUORelease.soloOnly { return .noServer }
        guard let b = backend, let user = b.session?.user.id else { return .signedOut }
        return user == snapshot.userID ? .linked : .noHome
    }

    // MARK: Budget partagé (les opérations sont des éléments synchronisés comme les tâches)
    var budgetRows: [(Record, BudgetEntry)] {
        records.compactMap { r in if case .budget(let e) = r.payload { return (r, e) }; return nil }
            .sorted { $0.1.date > $1.1.date }
    }
    var budgetEntries: [BudgetEntry] { budgetRows.map(\.1) }
    func addBudget(_ entry: BudgetEntry) {
        put(.budget(entry), isPrivate: !entry.shared)
    }
    func removeBudget(_ row: Record) { remove(row) }

    /// Les anciennes opérations (avant la version 1) deviennent des éléments partageables, une seule fois.
    func migrateLegacyBudget() {
        guard ready, let legacy = snapshot.manualBudget, !legacy.isEmpty else { return }
        transact { s in
            let known = Set(s.records.compactMap { r -> UUID? in if case .budget(let e) = r.payload { return e.id }; return nil })
            for e in legacy where !known.contains(e.id) {
                try s.put(Record(householdID: s.householdID, ownerID: e.shared ? nil : s.userID, payload: .budget(e)))
            }
            s.manualBudget = []
        }
    }

    /// En rejoignant le foyer, ce qui avait été saisi sur ce téléphone part avec (une seule fois par foyer).
    func importLocalDataIntoHome() {
        let key = "duo.imported." + snapshot.householdID.uuidString + "." + snapshot.userID.uuidString
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        guard let local = try? DiskStore(scope: "local"), let old = try? local.read() else { UserDefaults.standard.set(true, forKey: key); return }
        let existing = Set(snapshot.records.map(\.id))
        transact { s in
            for row in old.records where !row.deleted && !existing.contains(row.id) {
                var copy = Record(id: row.id, householdID: s.householdID, ownerID: row.ownerID == nil ? nil : s.userID, payload: row.payload)
                if case .task(var t) = copy.payload {
                    // L'ancien identifiant local de la personne devient celui du compte.
                    if t.assignee == old.userID.uuidString { t.assignee = s.userID.uuidString }
                    else if t.assignee == "partner-of:" + old.userID.uuidString { t.assignee = "partner-of:" + s.userID.uuidString }
                    copy.payload = .task(t)
                }
                try s.put(copy)
            }
            for e in old.manualBudget ?? [] {
                try s.put(Record(householdID: s.householdID, ownerID: e.shared ? nil : s.userID, payload: .budget(e)))
            }
        }
        if error == nil { UserDefaults.standard.set(true, forKey: key) }
    }

    /// Création de compte puis connexion immédiate (si la confirmation par e-mail est désactivée dans Supabase).
    func createAccountAndSignIn(email: String, password: String) async {
        await connect(email: email, password: password, createAccount: true)
        guard error == nil else { return }
        await connect(email: email, password: password, createAccount: false)
        if error != nil {
            error = "Compte créé. Si un e-mail de confirmation est arrivé, ouvre-le, puis touche « J'ai déjà un compte »."
        }
        if linkState == .linked { await sync(showErrors: false) }
    }

    var lastSyncText: String {
        guard let d = lastSuccessfulSync else { return syncInFlight ? "Synchronisation…" : "Pas encore synchronisé" }
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "Synchronisé à l'instant" }
        if s < 3600 { return "Synchronisé il y a \(s / 60) min" }
        return "Synchronisé à " + d.formatted(date: .omitted, time: .shortened)
    }
}

struct Appointment { let title: String; let date: Date }

extension AppStore {
    /// Revenus moins dépenses et épargne du mois en cours (opérations communes et les miennes).
    var monthLeft: Double {
        let cal = Calendar.current, now = Date()
        let month = budgetEntries.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        let income = month.filter { $0.kind == .income }.map(\.cents).reduce(0, +)
        let out = month.filter { $0.kind != .income }.map(\.cents).reduce(0, +)
        return Double(income - out) / 100
    }
    /// Prochain rendez-vous : ceux de DUO et ceux des calendriers de l'iPhone (si autorisés).
    func nextAppointment(after now: Date) -> Appointment? {
        var list: [Appointment] = records.compactMap { r in
            if case .event(let e) = r.payload, e.start > now { return Appointment(title: e.title, date: e.start) }
            return nil
        }
        let cal = CalendarBridge.shared
        if cal.granted {
            for d in 0..<14 {
                let day = Calendar.current.date(byAdding: .day, value: d, to: now) ?? now
                for ev in cal.events(on: day) where !ev.isAllDay && ev.startDate > now { list.append(Appointment(title: ev.title ?? "Rendez-vous", date: ev.startDate)) }
            }
        }
        return list.min { $0.date < $1.date }
    }
}

// MARK: Données d'exemple pour les captures automatiques (uniquement avec -duo-ui-test -duo-demo)
extension AppStore {
    func seedDemoIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard DUORelease.uiTesting, args.contains("-duo-demo"), records.isEmpty else { return }
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: cal.date(byAdding: .day, value: d, to: today)!)! }
        transact { s in
            let me = s.userID.uuidString, other = "partner-of:" + s.userID.uuidString
            for (t, a, d) in [("Vider le lave-vaisselle", me, 0), ("Passer l'aspirateur au salon", other, 0), ("Changer les draps", "Ensemble", 1), ("Nettoyer la douche", me, 2), ("Arroser les plantes du salon", other, 0)] {
                try s.put(Record(householdID: s.householdID, payload: .task(HouseTask(title: t, assignee: a, due: at(d, 19)))))
            }
            for n in ["Lait", "Pâtes", "Tomates", "Papier toilette"] { try s.putShopping(Shopping(ingredient: Ingredient(n, 1, .piece))) }
            for (n, loc, d) in [("Yaourts", "Frigo", 1), ("Poulet", "Frigo", 2), ("Courgettes", "Frigo", 5), ("Petits pois", "Congélateur", 60), ("Riz", "Placard", 200), ("Fromage râpé", "Frigo", 9)] {
                try s.put(Record(householdID: s.householdID, payload: .food(Food(name: n, quantity: 1, unit: .piece, location: loc, expiry: at(d, 0)))))
            }
            try s.put(Record(householdID: s.householdID, payload: .event(Event(title: "Dentiste Lilou", start: at(1, 14), end: at(1, 15)))))
            try s.put(Record(householdID: s.householdID, payload: .event(Event(title: "Repas chez les parents", start: at(4, 12), end: at(4, 15)))))
            for (t, k, c, p, sh) in [("Paie Théo", BudgetKind.income, 165000, "Théo", false), ("Paie Lilou", .income, 152000, "Lilou", false), ("Loyer", .expense, 72000, "Théo", true), ("Courses Leclerc", .expense, 8640, "Lilou", true), ("Livret A", .savings, 30000, "Théo", false)] {
                try s.put(Record(householdID: s.householdID, payload: .budget(BudgetEntry(date: at(0, 9), kind: k, cents: c, title: t, person: p, shared: sh))))
            }
        }
        if let r = suggestions.first { put(.meal(Meal(recipeID: r.id, date: at(0, 19, 30)))) }
    }
}
