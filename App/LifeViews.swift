import SwiftUI
import DUOCore

struct PlanningView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date(); @State private var week = false; @State private var adding = false; @State private var cooking: Record?
    private var interval: DateInterval { Calendar.current.dateInterval(of: week ? .weekOfYear : .day, for: date)! }
    private var events: [Record] { store.records.filter { if case .event(let e) = $0.payload { return e.start < interval.end && e.end > interval.start }; return false }.sorted { a,b in if case .event(let x) = a.payload, case .event(let y) = b.payload { return x.start < y.start }; return false } }
    var body: some View {
        List {
            Section { DatePicker("Date", selection: $date, displayedComponents: [.date]); Toggle("Vue semaine", isOn: $week); Button("Ajouter un événement") { adding = true } }
            Section("Au fil de la journée") {
                if events.isEmpty { Text("Aucun événement prévu.").foregroundStyle(Color("SecondaryReadable")) }
                ForEach(events) { row in
                    if case .event(let e) = row.payload {
                        NavigationLink { ItemEditor(kind: "event", row: row) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(e.start.formatted(date: week ? .abbreviated : .omitted, time: .shortened) + " — " + e.end.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit()).foregroundStyle(Color("SecondaryReadable"))
                                Label(e.title, systemImage: e.sport ? "figure.run" : "calendar")
                                if row.ownerID != nil { Label("Privé", systemImage: "lock").font(.caption) }
                                if events.contains(where: { other in if other.id != row.id, case .event(let x) = other.payload { return e.overlaps(x) }; return false }) { Label("Chevauchement horaire", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Color("Error")) }
                                if e.timeZone != TimeZone.current.identifier { Text("Fuseau d’origine : \(e.timeZone)").font(.caption) }
                            }
                        }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } }
                    }
                }
            }
            Section("À table") {
                ForEach(store.records.filter { if case .meal(let m) = $0.payload { return interval.contains(m.date) }; return false }) { row in
                    if case .meal(let meal) = row.payload, let recipe = Catalog.recipes.first(where: { $0.id == meal.recipeID }) {
                        VStack(alignment: .leading, spacing: 10) {
                            NavigationLink { RecipeView(recipe: recipe) } label: { Text(recipe.title).font(.headline) }
                            Text("\(meal.portions) portions · " + meal.date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                            if meal.cooked { Label("Cuisiné", systemImage: "checkmark.circle") }
                            else {
                                Button("Nous avons cuisiné ce repas") { cooking = row }.buttonStyle(.borderless)
                                Menu("Remplacer la recette") {
                                    ForEach(store.suggestions.filter { $0.id != meal.recipeID }) { alternative in Button(alternative.title) { var changed = meal; changed.recipeID = alternative.id; store.put(.meal(changed), editing: row); store.refreshShopping() } }
                                }.buttonStyle(.borderless)
                            }
                        }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row); store.refreshShopping() } }
                    }
                }
            }
            Section("Tâches planifiées") {
                ForEach(store.records.filter { if case .task(let t) = $0.payload, let due = t.due { return t.completed == nil && interval.contains(due) }; return false }) { row in if case .task(let t) = row.payload { Button(t.title) { store.toggle(row) } } }
            }
        }.sheet(isPresented: $adding) { NavigationStack { ItemEditor(kind: "event") } }
        .confirmationDialog("Confirmer les quantités utilisées et déduire le stock ?", isPresented: Binding(get: { cooking != nil }, set: { if !$0 { cooking = nil } }), titleVisibility: .visible) {
            Button("Confirmer et déduire le stock") { if let cooking { store.cook(cooking) }; cooking = nil }
            Button("Annuler", role: .cancel) { cooking = nil }
        }
        .scrollContentBackground(.hidden).background(Color("Background"))
    }
}
struct HouseholdView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false; @State private var history = false
    var body: some View {
        List {
            Section { NavigationLink { HabitsView() } label: { Label("Sport & habitudes", systemImage: "figure.mind.and.body") }; Button("Ajouter une tâche") { adding = true }; Toggle("Voir l’historique", isOn: $history) }
            Section(history ? "Actions accomplies" : "À faire, à votre rythme") {
                let tasks = store.records.filter { if case .task(let t) = $0.payload { return (t.completed != nil) == history }; return false }
                if tasks.isEmpty { Text(history ? "L’historique est vide." : "Tout est tranquille pour le moment.").foregroundStyle(Color("SecondaryReadable")) }
                ForEach(tasks) { row in
                    if case .task(let t) = row.payload {
                        HStack {
                            if !history { Button { store.toggle(row) } label: { Image(systemName: "circle").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel("Terminer \(t.title)") }
                            NavigationLink { ItemEditor(kind: "task", row: row) } label: {
                                VStack(alignment: .leading, spacing: 4) { Text(t.title); Text(store.assigneeLabel(t.assignee)).font(.caption).foregroundStyle(Color("SecondaryReadable")); if let due = t.due { Text(due.formatted(date: .abbreviated, time: .shortened)).font(.caption) }; if let done = t.completed { Text("Terminée " + done.formatted(date: .abbreviated, time: .shortened)).font(.caption) } }
                            }
                        }.contextMenu { if !history { Button("Me rappeler à l’échéance") { Task { await store.remind(row) } } } }
                        .swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } }
                    }
                }
            }
            if !store.snapshot.conflicts.isEmpty {
                Section("Modifications simultanées") {
                    ForEach(store.snapshot.conflicts) { conflict in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(conflict.local.payload.kind) · conflit de versions").font(.headline)
                            Text("Cet iPhone : " + describe(conflict.local))
                            Text("Autre version : " + describe(conflict.remote))
                            Button("Conserver cet iPhone") { store.resolve(conflict, keepLocal: true) }
                            Button("Conserver l’autre version") { store.resolve(conflict, keepLocal: false) }
                        }.buttonStyle(.borderless)
                    }
                }
            }
        }.sheet(isPresented: $adding) { NavigationStack { ItemEditor(kind: "task") } }
        .scrollContentBackground(.hidden).background(Color("Background"))
    }
    private func describe(_ row: Record) -> String {
        if row.deleted { return "Supprimé" }
        switch row.payload {
        case .food(let f): return "\(f.name) · \(f.quantity.formatted()) \(f.unit.label) · \(f.location)"
        case .shopping(let s): return "\(s.ingredient.name) · \(s.ingredient.quantity.formatted()) · \(s.checked ? "acheté" : "à acheter")"
        case .meal(let m): return "\(m.recipeID) · \(m.portions) portions · \(m.cooked ? "cuisiné" : "prévu")"
        case .task(let t): return "\(t.title) · \(t.assignee) · \(t.completed == nil ? "à faire" : "terminée")"
        case .event(let e): return e.title + " · " + e.start.formatted()
        case .habit(let h): return "\(h.title) · objectif \(h.weeklyGoal) · \(h.completions.count) validations"
        }
    }
}
struct HabitsView: View {
    @Environment(AppStore.self) private var store; @State private var addHabit = false; @State private var addSport = false
    var body: some View {
        List {
            Section { Text("Chaque petit pas compte. Vos objectifs peuvent évoluer avec vous."); Button("Créer une habitude") { addHabit = true }; Button("Prévoir une séance") { addSport = true } }
            Section("Cette semaine") {
                ForEach(store.records.filter { if case .habit = $0.payload { return true }; return false }) { row in
                    if case .habit(let h) = row.payload {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink { ItemEditor(kind: "habit", row: row) } label: { Label(h.title, systemImage: row.ownerID == nil ? "person.2" : "lock") }
                            ProgressView(value: Double(min(h.progress(at: Date()), h.weeklyGoal)), total: Double(h.weeklyGoal)).accessibilityLabel("\(h.progress(at: Date())) jours sur un objectif de \(h.weeklyGoal)")
                            Button(h.completions.contains(where: { Calendar.current.isDateInToday($0) }) ? "Annuler aujourd’hui" : "Fait aujourd’hui") { store.toggle(row) }.buttonStyle(.borderless)
                        }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } }
                    }
                }
            }
            Section("Séances et activités enregistrées") {
                ForEach(store.records.filter { if case .event(let e) = $0.payload { return e.sport }; return false }) { row in
                    if case .event(let e) = row.payload { NavigationLink { ItemEditor(kind: "sport", row: row) } label: { VStack(alignment: .leading) { Text(e.title); Text(e.start.formatted()).font(.caption); Text(e.end < Date() ? "Activité passée (déclarative)" : "Séance prévue").font(.caption) } }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } } }
                }
            }
        }.navigationTitle("À votre rythme")
        .sheet(isPresented: $addHabit) { NavigationStack { ItemEditor(kind: "habit") } }
        .sheet(isPresented: $addSport) { NavigationStack { ItemEditor(kind: "sport") } }
    }
}
