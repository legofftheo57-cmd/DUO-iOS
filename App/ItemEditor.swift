import SwiftUI
import DUOCore

struct ItemEditor: View {
    @Environment(AppStore.self) private var store; @Environment(\.dismiss) private var dismiss
    let kind: String; var row: Record?
    @State private var name = ""; @State private var quantity = 1.0; @State private var unit = FoodUnit.piece
    @State private var category = "Autres"; @State private var location = "Frigo"; @State private var hasDate = false
    @State private var start = Date(); @State private var end = Date().addingTimeInterval(3600)
    @State private var assignee = "Ensemble"; @State private var repeatDays = 0; @State private var goal = 3
    @State private var isPrivate = false; @State private var loaded = false
    var body: some View {
        Form {
            if let error = store.error { Text(error).foregroundStyle(Color("Error")) }
            TextField(kind == "food" ? "Aliment" : "Nom", text: $name).accessibilityIdentifier("itemName")
            if kind == "food" || kind == "shopping" {
                TextField("Quantité", value: $quantity, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("itemQuantity")
                Picker("Unité", selection: $unit) { ForEach(FoodUnit.allCases, id: \.self) { Text($0.label).tag($0) } }
                Picker("Catégorie", selection: $category) { ForEach(["Autres", "Fruits et légumes", "Frais", "Épicerie", "Surgelés", "Entretien", "Alimentation"], id: \.self) { Text($0) } }
            }
            if kind == "food" {
                Picker("Emplacement", selection: $location) { ForEach(["Frigo", "Congélateur", "Placard"], id: \.self) { Text($0) } }
                Toggle("Date limite connue", isOn: $hasDate)
                if hasDate { DatePicker("À vérifier le", selection: $start, displayedComponents: [.date]) }
                Text("Utilisez le même nom que dans les recettes : carotte, riz, œufs… Les variantes de produits ne sont pas substituées automatiquement.").font(.caption)
            }
            if kind == "task" {
                if DUORelease.soloOnly {
                    Label("Tâche personnelle", systemImage: "iphone").font(.subheadline)
                } else {
                    Picker("Attribution", selection: $assignee) { Text("Ensemble").tag("Ensemble"); Text("Moi").tag(store.snapshot.userID.uuidString); Text("Mon partenaire").tag("partner-of:" + store.snapshot.userID.uuidString) }
                }
                Toggle("Échéance", isOn: $hasDate)
                if hasDate { DatePicker("À faire avant", selection: $start) }
                Stepper(repeatDays == 0 ? "Sans récurrence" : "Tous les \(repeatDays) jour(s)", value: $repeatDays, in: 0...365)
                HStack { Button("Chaque jour") { repeatDays = 1 }; Button("Chaque semaine") { repeatDays = 7 } }.buttonStyle(.borderless)
            }
            if kind == "event" || kind == "sport" { DatePicker("Début", selection: $start); DatePicker("Fin", selection: $end); Text("Horaires affichés dans le fuseau actuel : \(TimeZone.current.identifier)").font(.caption) }
            if kind == "habit" { Stepper("Objectif : \(goal) jours par semaine", value: $goal, in: 1...7) }
            if ["task", "event", "sport", "habit"].contains(kind) {
                Toggle("Privé", isOn: $isPrivate).disabled(row != nil)
                Text(row == nil ? "Les séances et habitudes sont privées par défaut. Désactivez seulement si vous souhaitez les partager." : "La visibilité est fixée à la création pour protéger les données déjà partagées.").font(.caption)
            }
            Button { save() } label: {
                Text(row == nil ? "Ajouter" : "Enregistrer les modifications")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("saveItem")
        }.navigationTitle(editorTitle)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        .onAppear { load() }
    }
    private var editorTitle: String {
        if row != nil { return "Modifier" }
        switch kind {
        case "food": return "Nouvel aliment"
        case "shopping": return "Nouvel article"
        case "task": return "Nouvelle tâche"
        case "event": return "Nouveau rendez-vous"
        case "sport": return "Nouvelle séance"
        case "habit": return "Nouvelle habitude"
        default: return "Ajouter"
        }
    }
    private func load() {
        guard !loaded else { return }; loaded = true; isPrivate = kind == "sport" || kind == "habit"
        guard let row else { return }; isPrivate = row.ownerID != nil
        switch row.payload {
        case .food(let f): name = f.name; quantity = f.quantity; unit = f.unit; category = f.category; location = f.location; hasDate = f.expiry != nil; start = f.expiry ?? Date()
        case .shopping(let s): name = s.ingredient.name; quantity = s.ingredient.quantity; unit = s.ingredient.unit; category = s.category
        case .task(let t): name = t.title; assignee = t.assignee; repeatDays = t.repeatDays; hasDate = t.due != nil; start = t.due ?? Date()
        case .event(let e): name = e.title; start = e.start; end = e.end
        case .habit(let h): name = h.title; goal = h.weeklyGoal
        case .meal: break
        }
    }
    private func save() {
        let payload: Content
        switch kind {
        case "food":
            var f = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), quantity: quantity, unit: unit, category: category, location: location, expiry: hasDate ? Calendar.current.startOfDay(for: start) : nil)
            if case .food(let old) = row?.payload { f.added = old.added }; payload = .food(f)
        case "shopping":
            var s = Shopping(ingredient: Ingredient(name, quantity, unit)); s.category = category
            if case .shopping(let old) = row?.payload { s.checked = old.checked; s.generated = false }; payload = .shopping(s)
        case "task":
            let ownerLabel = DUORelease.soloOnly && row == nil ? store.snapshot.userID.uuidString : assignee
            var t = HouseTask(title: name, assignee: ownerLabel, due: hasDate ? start : nil, repeatDays: repeatDays)
            if case .task(let old) = row?.payload { t.completed = old.completed }; payload = .task(t)
        case "habit":
            var h = Habit(title: name, weeklyGoal: goal); if case .habit(let old) = row?.payload { h.completions = old.completions }; payload = .habit(h)
        default: payload = .event(Event(title: name, start: start, end: end, sport: kind == "sport" || { if case .event(let old) = row?.payload { return old.sport }; return false }()))
        }
        store.put(payload, editing: row, isPrivate: isPrivate); if store.error == nil { dismiss() }
    }
}
