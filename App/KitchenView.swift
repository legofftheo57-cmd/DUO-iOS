import SwiftUI
import DUOCore

struct KitchenView: View {
    @Environment(AppStore.self) private var store
    @State private var search = ""; @State private var location = "Tous"; @State private var adding = false; @State private var planning = false
    var body: some View {
        List {
            Section {
                Button { adding = true } label: { Label("Ajouter un aliment", systemImage: "plus") }.accessibilityIdentifier("addFood")
                Picker("Emplacement", selection: $location) { ForEach(["Tous", "Frigo", "Congélateur", "Placard"], id: \.self) { Text($0) } }
            }
            Section("En stock") {
                let rows = store.records.filter { if case .food(let f) = $0.payload { return (search.isEmpty || normalized(f.name).contains(normalized(search))) && (location == "Tous" || f.location == location) }; return false }
                if rows.isEmpty { ContentUnavailableView("Votre cuisine commence ici", systemImage: "carrot", description: Text("Ajoutez un aliment pour adapter les recettes.")) }
                ForEach(rows) { row in
                    if case .food(let f) = row.payload {
                        NavigationLink { ItemEditor(kind: "food", row: row) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(f.name).font(.headline)
                                Text("\(f.quantity.formatted()) \(f.unit.label) · \(f.location)").foregroundStyle(Color("SecondaryReadable"))
                                if let expiry = f.expiry { Text("À vérifier : " + expiry.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(expiry < Date() ? Color("Error") : Color("SecondaryReadable")) }
                            }
                        }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } }
                    }
                }
            }
            Section("À cuisiner") {
                Button("Composer plusieurs dîners") { planning = true }
                ForEach(store.suggestions) { recipe in NavigationLink { RecipeView(recipe: recipe) } label: { VStack(alignment: .leading) { Text(recipe.title); Text("\(recipe.preparation + recipe.cooking) min · \(MealEngine.missing(recipe.ingredients, stock: store.foods).count) ingrédient(s) à compléter").font(.caption).foregroundStyle(Color("SecondaryReadable")) } } }
                if store.suggestions.isEmpty { Text("Aucune recette compatible avec vos exclusions.") }
            }
        }.searchable(text: $search, prompt: "Rechercher un aliment")
        .scrollContentBackground(.hidden).background(Color("Background"))
        .sheet(isPresented: $adding) { NavigationStack { ItemEditor(kind: "food") } }
        .sheet(isPresented: $planning) { NavigationStack { MealPlanForm() } }
    }
}
struct RecipeView: View {
    @Environment(AppStore.self) private var store
    let recipe: Recipe
    @State private var portions = 2; @State private var date = Date(); @State private var step = 0
    var needs: [Ingredient] { (try? MealEngine.requirements([Meal(recipeID: recipe.id, date: date, portions: portions)], catalog: Catalog.recipes)) ?? [] }
    var body: some View {
        List {
            Section {
                Text(recipe.title).font(.largeTitle.bold())
                Label("Préparation \(recipe.preparation) min · cuisson \(recipe.cooking) min", systemImage: "clock")
                Stepper("\(portions) portions", value: $portions, in: 1...12)
                Text("Allergènes : " + (recipe.allergens.isEmpty ? "aucun identifié dans les ingrédients de base" : recipe.allergens.joined(separator: ", "))).font(.caption)
                Text("Vérifiez toujours les étiquettes et les traces éventuelles des produits.").font(.caption).foregroundStyle(Color("SecondaryReadable"))
            }
            Section("Ingrédients") {
                ForEach(needs, id: \.key) { i in
                    let missing = MealEngine.missing([i], stock: store.foods).first?.quantity ?? 0
                    HStack { Text(i.name); Spacer(); Text("\(i.quantity.formatted()) \(i.unit.label)") }
                    if missing > 0 { Text("Manque \(missing.formatted()) \(i.unit.label)").font(.caption).foregroundStyle(Color("SecondaryReadable")) }
                }
            }
            Section("À votre rythme · étape \(step + 1)/\(recipe.steps.count)") {
                Text(recipe.steps[step]).font(.body).padding(.vertical)
                HStack { Button("Précédente") { step -= 1 }.disabled(step == 0); Spacer(); Button("Suivante") { step += 1 }.disabled(step == recipe.steps.count - 1) }.buttonStyle(.borderless)
            }
            Section("Prévoir ce repas") {
                DatePicker("Date", selection: $date, displayedComponents: [.date])
                Button("Ajouter au planning") { store.put(.meal(Meal(recipeID: recipe.id, date: date, portions: portions))); store.refreshShopping() }
                Text("Le stock n’est déduit qu’après confirmation dans le planning.").font(.caption)
            }
        }.navigationTitle("Recette").navigationBarTitleDisplayMode(.inline)
    }
}
struct MealPlanForm: View {
    @Environment(AppStore.self) private var store; @Environment(\.dismiss) private var dismiss
    @State private var count = 5; @State private var portions = 2; @State private var budget = 35.0; @State private var date = Date()
    var body: some View {
        Form {
            Stepper("\(count) dîners", value: $count, in: 1...12)
            Stepper("\(portions) personnes", value: $portions, in: 1...12)
            DatePicker("À partir du", selection: $date, displayedComponents: [.date])
            TextField("Budget indicatif (€)", value: $budget, format: .number).keyboardType(.decimalPad)
            Text("Aucun prix magasin connecté : le respect du budget n’est pas vérifiable. DUO privilégie le stock, les ingrédients communs et la variété.").foregroundStyle(Color("SecondaryReadable"))
            Text("Les repas s’ajoutent au planning existant. Les courses sont recalculées pour tous les repas non cuisinés.").font(.caption)
            Button("Préparer les repas et les courses") { store.generate(count: count, portions: portions, budget: budget, start: date); if store.error == nil { dismiss() } }.disabled(!budget.isFinite || budget <= 0)
        }.navigationTitle("Nos prochains dîners").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
    }
}
struct ShoppingView: View {
    @Environment(AppStore.self) private var store; @State private var adding = false
    var body: some View {
        List {
            Section { Text("Prix non renseignés · budget non vérifiable").font(.subheadline).foregroundStyle(Color("SecondaryReadable")); Button("Recalculer depuis le planning") { store.refreshShopping() }; Button("Ajouter un article") { adding = true } }
            ForEach([false, true], id: \.self) { checked in
                Section(checked ? "Dans le panier" : "À acheter") {
                    ForEach(store.records.filter { if case .shopping(let s) = $0.payload { return s.checked == checked }; return false }) { row in
                        if case .shopping(let s) = row.payload {
                            HStack {
                                Button { store.toggle(row) } label: { Image(systemName: s.checked ? "checkmark.circle.fill" : "circle").frame(width: 44, height: 44) }.buttonStyle(.borderless).accessibilityLabel(s.checked ? "Remettre \(s.ingredient.name) à acheter" : "Cocher \(s.ingredient.name)")
                                NavigationLink { ItemEditor(kind: "shopping", row: row) } label: { VStack(alignment: .leading) { Text(s.ingredient.name).strikethrough(s.checked); Text("\(s.ingredient.quantity.formatted()) \(s.ingredient.unit.label) · \(s.category)").font(.caption).foregroundStyle(Color("SecondaryReadable")) } }
                            }.swipeActions { Button("Supprimer", role: .destructive) { store.remove(row) } }
                        }
                    }
                }
            }
            Section { Text("Cocher un article ne l’ajoute pas au frigo. Enregistrez les achats reçus avant de recalculer les courses.").font(.caption) }
        }.sheet(isPresented: $adding) { NavigationStack { ItemEditor(kind: "shopping") } }
        .scrollContentBackground(.hidden).background(Color("Background"))
    }
}
