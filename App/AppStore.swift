import SwiftUI
import Observation
import DUOCore
import UserNotifications

@MainActor @Observable final class AppStore {
    var snapshot = Snapshot(); var error: String?; var status = "Sur cet iPhone"; var syncing = false; var ready = false
    var lastSuccessfulSync: Date?
    var backend: Backend?; var pendingInvitation: String?; private var disk: DiskStore?
    var records: [Record] { snapshot.records.filter { !$0.deleted } }
    var foods: [Food] { records.compactMap { if case .food(let f) = $0.payload { return f }; return nil } }
    var meals: [Meal] { records.compactMap { if case .meal(let m) = $0.payload { return m }; return nil } }
    var exclusions: Set<String> { Set(UserDefaults.standard.string(forKey: "exclusions", default: "").split(separator: ",").map { normalized(String($0)) }) }
    var suggestions: [Recipe] { MealEngine.suggestions(catalog: Catalog.recipes, stock: foods, exclusions: exclusions, recent: meals.filter { $0.date > Date().addingTimeInterval(-7 * 86400) }.map(\.recipeID)) }
    init() {
        pendingInvitation = InviteVault.load()
        do { let args = ProcessInfo.processInfo.arguments; let index = args.firstIndex(of: "-duo-ui-test"); let scope = index != nil && args.count > index! + 1 ? "ui-test-" + args[index! + 1] : "local"; let local = try DiskStore(scope: scope); snapshot = try local.read() ?? Snapshot(); disk = local; ready = true }
        catch { self.error = error.localizedDescription }
        // A saved session is not used to send local data. Reconnection selects an isolated user cache.
    }
    func transact(_ change: (inout Snapshot) throws -> Void) {
        guard ready, !syncing else { error = "Veuillez attendre la fin de l’opération."; return }
        error = nil
        do { var next = snapshot; try change(&next); guard let disk else { throw DuoError.invalid("Stockage indisponible.") }; try disk.write(next); snapshot = next }
        catch { self.error = error.localizedDescription }
    }
    func put(_ payload: Content, editing row: Record? = nil, isPrivate: Bool = false) {
        transact { s in
            var row = row ?? Record(householdID: s.householdID, ownerID: isPrivate ? s.userID : nil, payload: payload)
            if case .food(let food) = payload {
                let duplicate = s.records.contains { other in
                    guard other.id != row.id, !other.deleted, case .food(let f) = other.payload else { return false }
                    return normalized(f.name) == normalized(food.name) && f.unit.dimension == food.unit.dimension && f.location == food.location && f.expiry == food.expiry
                }
                guard !duplicate else { throw DuoError.invalid("Cet aliment existe déjà avec le même emplacement et la même date. Modifiez sa quantité.") }
            }
            row.payload = payload; try s.put(row)
        }
        if error == nil, let row { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [row.id.uuidString]) }
    }
    func remove(_ row: Record) { transact { s in var r = row; r.deleted = true; try s.put(r) }; if error == nil { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [row.id.uuidString]) } }
    func toggle(_ row: Record) {
        transact { s in
            var r = row
            switch r.payload {
            case .shopping(var item): item.checked.toggle(); r.payload = .shopping(item)
            case .task(var task):
                guard task.completed == nil else { return }
                let now = Date(); task.completed = now; r.payload = .task(task)
                if let due = TimeRules.nextDue(task, completion: now) {
                    let next = HouseTask(title: task.title, assignee: task.assignee, due: due, repeatDays: task.repeatDays)
                    let nextID = TimeRules.nextTaskID(r.id)
                    try s.put(Record(id: nextID, householdID: s.householdID, ownerID: r.ownerID, payload: .task(next)))
                }
            case .habit(var habit):
                let today = Calendar.current.startOfDay(for: Date())
                if habit.completions.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) { habit.completions.removeAll { Calendar.current.isDate($0, inSameDayAs: today) } }
                else { habit.completions.append(today) }; r.payload = .habit(habit)
            default: return
            }
            try s.put(r)
        }
        if error == nil { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [row.id.uuidString]) }
    }
    func generate(count: Int, portions: Int, budget: Double, start: Date) {
        do {
            let generated = try MealEngine.plan(count: count, portions: portions, start: start, catalog: Catalog.recipes, stock: foods, exclusions: exclusions, recent: meals.map(\.recipeID), budget: budget, prices: [])
            guard generated.count == count else { throw DuoError.invalid("Pas assez de recettes différentes compatibles. Réduisez le nombre de repas ou adaptez les exclusions.") }
            transact { s in for m in generated { try s.put(Record(householdID: s.householdID, payload: .meal(m))) }; try rebuildShopping(&s) }
        } catch { self.error = error.localizedDescription }
    }
    func rebuildShopping(_ s: inout Snapshot) throws {
        let active = s.records.filter { !$0.deleted }
        let meals = active.compactMap { r -> Meal? in if case .meal(let m) = r.payload { return m }; return nil }
        let food = active.compactMap { r -> Food? in if case .food(let f) = r.payload { return f }; return nil }
        let rawNeeds = try MealEngine.missingForMeals(meals, catalog: Catalog.recipes, stock: food)
        let manual = active.compactMap { row -> Food? in
            if case .shopping(let item) = row.payload, !item.checked, !item.generated { return Food(name: item.ingredient.name, quantity: item.ingredient.quantity, unit: item.ingredient.unit) }; return nil
        }
        let need = MealEngine.missing(rawNeeds, stock: manual)
        // Generated lines are replaced, manual and bought lines retained. Bought items do not become stock silently.
        for var row in active { if case .shopping(let item) = row.payload, item.generated && !item.checked { row.deleted = true; try s.put(row) } }
        for ingredient in need { try s.put(Record(householdID: s.householdID, payload: .shopping(Shopping(ingredient: ingredient, generated: true)))) }
    }
    func refreshShopping() { transact { try rebuildShopping(&$0) } }
    func cook(_ row: Record) {
        transact { s in
            guard case .meal(var meal) = row.payload, !meal.cooked else { return }
            let needs = try MealEngine.requirements([meal], catalog: Catalog.recipes)
            let changed = try MealEngine.consume(needs, stock: s.records)
            for (before, after) in zip(s.records, changed) where before != after { try s.put(after) }
            meal.cooked = true; var r = row; r.payload = .meal(meal); try s.put(r); try rebuildShopping(&s)
        }
    }
    func connect(email: String, password: String, createAccount: Bool) async {
        guard !syncing else { return }; syncing = true; error = nil; defer { syncing = false }
        do {
            let b = try Backend()
            if createAccount { try await b.signup(email: email, password: password); status = "Vérifiez votre e-mail, puis connectez-vous."; return }
            if !password.isEmpty { try await b.login(email: email, password: password) } else { try await b.refresh() }
            guard let user = b.session?.user.id else { throw DuoError.unauthorized }
            if let home = try await b.household() { try selectCache(user: user, home: home); status = "Compte connecté" }
            else { status = "Compte connecté : créez ou rejoignez un foyer." }
            backend = b; lastSuccessfulSync = nil
        } catch { self.error = error.localizedDescription }
    }
    private func selectCache(user: UUID, home: UUID) throws {
        let nextDisk = try DiskStore(scope: user.uuidString + "-" + home.uuidString)
        let next = try nextDisk.read() ?? Snapshot(householdID: home, userID: user)
        guard next.userID == user, next.householdID == home else { throw DuoError.unauthorized }
        disk = nextDisk; snapshot = next; ready = true; lastSuccessfulSync = nil
    }
    func receiveInviteURL(_ url: URL) {
        guard let token = InviteLink.read(url) else { error = "Lien d’invitation DUO invalide."; return }
        pendingInvitation = token
        do { try InviteVault.save(token) } catch { self.error = error.localizedDescription }
        status = "Invitation reçue. Connectez-vous, puis confirmez pour rejoindre le foyer."
    }
    func setupHome(invitation: String?) async {
        guard !syncing, let b = backend, let user = b.session?.user.id else { return }; syncing = true; defer { syncing = false }
        do {
            let home: UUID
            if let invitation { home = try await b.rpc("join_household", ["p_token": invitation.trimmingCharacters(in: .whitespacesAndNewlines)], as: UUID.self) }
            else { home = try await b.rpc("create_household", as: UUID.self) }
            try selectCache(user: user, home: home); pendingInvitation = nil; InviteVault.clear(); status = "Foyer connecté • données locales conservées séparément"
        } catch { self.error = error.localizedDescription }
    }
    func invite() async -> String? {
        guard !syncing, let b = backend, b.session?.user.id == snapshot.userID else { return nil }
        syncing = true; error = nil; defer { syncing = false }
        do { try await b.refresh(); return try await b.rpc("invite_partner", as: String.self) }
        catch { self.error = error.localizedDescription; return nil }
    }
    func revokeInvitation() async -> Bool {
        guard !syncing, let b = backend, b.session?.user.id == snapshot.userID else {
            error = "Connectez-vous à votre foyer avant de révoquer une invitation."
            return false
        }
        syncing = true; defer { syncing = false }
        do {
            let revoked = try await b.rpc("revoke_invitation", as: Int.self)
            status = revoked > 0 ? "Invitation en attente révoquée" : "Aucune invitation active à révoquer"
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    func sync(showErrors: Bool = true) async {
        guard !syncing, let b = backend, b.session?.user.id == snapshot.userID else { return }
        syncing = true; defer { syncing = false }
        do {
            guard let disk else { throw DuoError.invalid("Stockage indisponible : synchronisation suspendue.") }
            try await b.refresh()
            var next = snapshot
            let incoming = try await b.fetch()
            for row in incoming {
                if let i = next.records.firstIndex(where: { $0.id == row.id }), next.pending.contains(row.id), row.payload == next.records[i].payload, row.deleted == next.records[i].deleted {
                    next.records[i] = row; next.pending.removeAll { $0 == row.id }; next.conflicts.removeAll { $0.id == row.id }
                } else { next.receive(row) }
            }
            // Save conflicts before any push, so interruption cannot lose either version.
            try disk.write(next); snapshot = next
            guard next.conflicts.isEmpty else { status = "Conflit à résoudre"; return }
            let pending = next.records.filter { next.pending.contains($0.id) }
            if !pending.isEmpty {
                let acknowledged = try await b.push(pending)
                for row in acknowledged { if let i = next.records.firstIndex(where: { $0.id == row.id }) { next.records[i] = row }; next.pending.removeAll { $0 == row.id } }
            }
            try disk.write(next); snapshot = next
            let obsoleteReminders = next.records.filter { row in
                if row.deleted { return true }; if case .task(let t) = row.payload { return t.completed != nil }; return false
            }.map { $0.id.uuidString }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: obsoleteReminders)
            if next.pending.isEmpty {
                lastSuccessfulSync = Date()
                status = "Synchronisé à " + (lastSuccessfulSync ?? Date()).formatted(date: .omitted, time: .shortened)
            } else {
                status = "Envoi partiel • \(next.pending.count) modification(s) à reprendre"
            }
            error = nil
        } catch { status = "Modifications conservées • synchronisation à reprendre"; if showErrors { self.error = error.localizedDescription } }
    }
    func resolve(_ conflict: Conflict, keepLocal: Bool) {
        transact { s in
            var row = keepLocal ? conflict.local : conflict.remote; row.revision = conflict.remote.revision
            s.conflicts.removeAll { $0.id == row.id }
            if keepLocal && conflict.remote.deleted && !conflict.local.deleted {
                s.pending.removeAll { $0 == row.id }
                if let i = s.records.firstIndex(where: { $0.id == row.id }) { s.records[i] = conflict.remote }
                row.id = UUID(); row.revision = 0; try s.put(row); return
            }
            if keepLocal { try s.put(row) } else { s.pending.removeAll { $0 == row.id }; if let i = s.records.firstIndex(where: { $0.id == row.id }) { s.records[i] = row } }
        }
    }
    func requestPasswordReset(email: String) async {
        guard !syncing else { return }
        syncing = true; error = nil; defer { syncing = false }
        do {
            let b = try Backend()
            try await b.requestPasswordReset(email: email)
            status = "Si cette adresse est enregistrée, un e-mail de récupération sera envoyé."
        } catch { self.error = error.localizedDescription }
    }
    func completePasswordReset(email: String, code: String, password: String) async {
        guard !syncing else { return }; syncing = true; error = nil; defer { syncing = false }
        do {
            let b = try Backend()
            try await b.completePasswordReset(email: email, token: code, newPassword: password)
            status = "Mot de passe modifié. Vous pouvez vous connecter."
        } catch { self.error = error.localizedDescription }
    }
    func prepareExport() throws -> URL {
        guard ready, !syncing else { throw DuoError.invalid("Attendez la fin de la synchronisation avant l’export.") }
        // No authentication tokens or Keychain material are serialized.
        let archive = DuoExport(exportedAt: Date(), scope: backend == nil ? "local" : "foyer", snapshot: snapshot)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DUO-export-" + UUID().uuidString + ".json")
        try encoder.encode(archive).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
    func previewLocalImport(from url: URL) throws -> Snapshot {
        guard DUORelease.soloOnly, backend == nil else {
            throw DuoError.invalid("La restauration est réservée au mode personnel hors ligne.")
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count <= 10_000_000 else {
            throw DuoError.invalid("Ce fichier est trop volumineux pour une sauvegarde DUO.")
        }
        let archive = try JSONDecoder().decode(DuoExport.self, from: data)
        guard archive.format == "DUO-export-v1", archive.scope == "local" else {
            throw DuoError.invalid("Seules les sauvegardes DUO locales sont acceptées.")
        }
        let checked = try Snapshot.decode(JSONEncoder().encode(archive.snapshot))
        guard checked.conflicts.isEmpty else {
            throw DuoError.invalid("La sauvegarde contient des conflits non résolus.")
        }
        return checked
    }
    func restoreLocalImport(_ imported: Snapshot) throws {
        guard DUORelease.soloOnly, backend == nil, ready, !syncing, let disk else {
            throw DuoError.invalid("La restauration locale est indisponible.")
        }
        let checked = try Snapshot.decode(JSONEncoder().encode(imported))
        try disk.write(checked)
        snapshot = checked
        status = "Sauvegarde restaurée sur cet iPhone"
        error = nil
    }
    func deleteAccount() async {
        guard !syncing, let backend, let user = backend.session?.user.id else { error = "Connectez-vous au compte à supprimer."; return }
        syncing = true; defer { syncing = false }
        do {
            try await backend.refresh()
            try await backend.deleteMyAccount()
            // Only wipe this device after server acknowledgement. On network error
            // preserve the cache and display an actionable failure.
            let cacheFailure: String?
            do { try DiskStore.deleteCaches(for: user); cacheFailure = nil }
            catch { cacheFailure = error.localizedDescription }
            self.backend = nil
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            let local = try DiskStore(scope: "local")
            snapshot = try local.read() ?? Snapshot(); disk = local
            status = "Compte supprimé du serveur • espace local indépendant conservé"
            self.error = cacheFailure.map { "Compte distant supprimé, mais nettoyage de fichiers locaux incomplet : " + $0 }
            return
        } catch {
            self.error = "Suppression non confirmée : " + error.localizedDescription + ". Réessayez après avoir vérifié votre connexion."
        }
    }
    func disconnect() async {
        guard !syncing else { return }
        // Hold the same operation lock as sync across the logout await.
        syncing = true; error = nil; defer { syncing = false }
        await backend?.logout(); backend = nil; lastSuccessfulSync = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        do { let local = try DiskStore(scope: "local"); snapshot = try local.read() ?? Snapshot(); disk = local; status = "Sur cet iPhone" }
        catch { ready = false; self.error = error.localizedDescription }
    }
    func restoreSessionIfAvailable() async {
        guard let b = try? Backend(), b.session != nil else { return }
        await connect(email: "", password: "", createAccount: false)
    }
    func assigneeLabel(_ value: String) -> String {
        if value == "Ensemble" { return value }
        if value == snapshot.userID.uuidString { return "Moi" }
        if value.hasPrefix("partner-of:") { return value == "partner-of:" + snapshot.userID.uuidString ? "Mon partenaire" : "Moi" }
        return "Mon partenaire"
    }
    func remind(_ row: Record) async {
        guard case .task(let task) = row.payload, let due = task.due, due > Date(), task.completed == nil else { error = "Choisissez une tâche à venir avec une échéance."; return }
        do {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { throw DuoError.invalid("Les notifications sont désactivées dans les réglages iOS.") }
            let content = UNMutableNotificationContent(); content.title = "DUO"; content.body = task.title; content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, due.timeIntervalSinceNow), repeats: false)
            try await center.add(UNNotificationRequest(identifier: row.id.uuidString, content: content, trigger: trigger))
            status = "Rappel programmé sur cet iPhone"
        } catch { self.error = error.localizedDescription }
    }
}
extension UserDefaults {
    func string(forKey key: String, default fallback: String) -> String { string(forKey: key) ?? fallback }
}

private struct DuoExport: Codable {
    let format: String
    let exportedAt: Date
    let scope: String
    let snapshot: Snapshot
    init(exportedAt: Date, scope: String, snapshot: Snapshot) {
        self.format = "DUO-export-v1"
        self.exportedAt = exportedAt
        self.scope = scope
        self.snapshot = snapshot
    }
}

