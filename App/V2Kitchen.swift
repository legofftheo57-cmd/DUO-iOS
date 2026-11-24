import SwiftUI
import DUOCore

struct KitchenV2: View {
    @Environment(AppStore.self) private var store
    @Binding var segment: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Repas · courses · chef").kicker()
                Text("Cuisine").font(P.serif(32)).foregroundStyle(P.text)
            }
            HStack(spacing: 4) {
                seg(0, "Repas"); seg(1, "Courses · \(store.shoppingRows.filter { !$0.1.checked }.count)"); seg(2, "Chef")
            }.padding(4).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            switch segment {
            case 0: MealsV2()
            case 1: ShoppingV2()
            default: ChefV2()
            }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }
    private func seg(_ i: Int, _ title: String) -> some View {
        Button { withAnimation(.snappy) { segment = i } } label: {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(segment == i ? P.ink : P.mut)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(segment == i ? P.text : .clear))
        }.buttonStyle(.plain).accessibilityAddTraits(segment == i ? .isSelected : [])
    }
}

struct MealsV2: View {
    @Environment(AppStore.self) private var store
    @State private var day = 0
    @State private var recipeShown: Recipe?
    private let names = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
    var body: some View {
        let start = Calendar.current.startOfDay(for: Date())
        let date = start.addingTimeInterval(Double(day) * 86400)
        let meal = store.meal(on: date)
        let recipe = meal.flatMap { store.recipe($0.1.recipeID) }
        let rest = day == 0 ? store.leftovers.first : nil
        let weekMeals = store.meals.filter { $0.date >= start && $0.date < start.addingTimeInterval(7 * 86400) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { i in
                        let d = start.addingTimeInterval(Double(i) * 86400)
                        Button { withAnimation(.snappy) { day = i } } label: {
                            VStack(spacing: 2) {
                                Text(names[DuoSchedule.isoWeekday(d) - 1]).font(.system(size: 10, weight: .bold)).opacity(0.7)
                                Text("\(Calendar.current.component(.day, from: d))").font(.system(size: 15, weight: .semibold))
                                Circle().fill(store.meal(on: d) != nil ? (day == i ? P.ink : P.butter) : .clear).frame(width: 4, height: 4)
                            }
                            .foregroundStyle(day == i ? P.ink : P.text)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(day == i ? P.butter : Color.white.opacity(0.04)))
                        }.buttonStyle(.plain)
                    }
                }
                HStack {
                    Text("Semaine estimée : ").foregroundStyle(P.mut) + Text(Brain.euros(Brain.weekCost(weekMeals))).foregroundStyle(P.mint).bold()
                    Spacer()
                    Button("Préparer la semaine") { store.planWeek() }.font(.system(size: 12, weight: .semibold)).foregroundStyle(P.lav)
                }.font(.system(size: 12))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(date.formatted(.dateTime.weekday(.wide)) + " · 19 h 30")
                        Spacer()
                        if let r = recipe { Text("\(r.preparation + r.cooking) min · ~\(Brain.euros(Catalog.cost[r.id] ?? 4))") }
                    }.font(.system(size: 11, weight: .bold)).tracking(1).textCase(.uppercase)
                    Text(rest?.1.name ?? recipe?.title ?? "Rien de prévu").font(P.serif(28)).lineLimit(3)
                    if let r = recipe, rest == nil { Text(r.ingredients.map(\.name).joined(separator: ", ")).font(.system(size: 13)).opacity(0.75) }
                    if rest != nil { Text("Il reste \(Int(rest!.1.quantity)) part(s) : rien à cuisiner ce soir.").font(.system(size: 13)).opacity(0.75) }
                    if let cook = DuoSchedule.cook(on: date), rest == nil {
                        HStack(spacing: 8) { Avatar(person: cook, size: 26); Text(cook == .lilou && DuoSchedule.isoWeekday(date) == 5 ? "Lilou finit à 16 h : elle cuisine" : "\(cook.rawValue) est libre plus tôt : c'est son tour").font(.system(size: 13, weight: .medium)) }
                    }
                    FlowButtons(meal: meal, recipe: recipe, rest: rest, show: { recipeShown = $0 }, date: date)
                }
                .foregroundStyle(P.ink).padding(20)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(LinearGradient(colors: [P.butter, Color(hex: 0xF3B79A)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .modifier(GentleTilt())

                if meal == nil && rest == nil {
                    Text("Idées avec ce que vous avez").kicker()
                    ForEach(Array(store.suggestions.prefix(3)), id: \.id) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.system(size: 15, weight: .medium)).foregroundStyle(P.text)
                                Text("\(r.preparation + r.cooking) min · ~\(Brain.euros(Catalog.cost[r.id] ?? 4))").font(.system(size: 12)).foregroundStyle(P.mut)
                            }
                            Spacer()
                            PillButton(title: "Au menu", fill: P.butter) {
                                let at = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: date) ?? date
                                store.put(.meal(Meal(recipeID: r.id, date: at))); if store.error == nil { store.toast = "Au menu · courses mises à jour" }
                            }
                        }.padding(14).glass(20)
                    }
                }
            }.padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $recipeShown) { r in NavigationStack { RecipeView(recipe: r).navigationTitle(r.title) } }
    }

    struct FlowButtons: View {
        @Environment(AppStore.self) private var store
        let meal: (Record, Meal)?; let recipe: Recipe?; let rest: (Record, Food)?; let show: (Recipe) -> Void; let date: Date
        var body: some View {
            HStack(spacing: 6) {
                if let rest {
                    small("On les a mangés", dark: true) { store.remove(rest.0); store.log(.mealCooked, rest.1.name); store.toast = "Restes finis · frigo à jour" }
                } else if let meal, let recipe {
                    small(meal.1.cooked ? "Mangé" : "On l'a mangé", dark: true) { store.markCooked(meal.0) }
                    small("Il en reste") { store.addLeftover(from: meal.0) }
                    small("Recette") { show(recipe) }
                    if !meal.1.cooked { small("Changer") { store.swapMeal(meal.0) } }
                }
            }.padding(.top, 6)
        }
        private func small(_ t: String, dark: Bool = false, _ a: @escaping () -> Void) -> some View {
            Button(action: { withAnimation { a() } }) {
                Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(dark ? P.butter : P.ink)
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background(Capsule().fill(dark ? P.ink : P.ink.opacity(0.1)))
            }.buttonStyle(.plain)
        }
    }
}

struct ShoppingV2: View {
    @Environment(AppStore.self) private var store
    @State private var newItem = ""
    private let quick = ["Pain", "Œufs", "Lait", "Bananes", "Papier toilette", "Pâtes"]
    var body: some View {
        let rows = store.shoppingRows
        let groups = Dictionary(grouping: rows) { $0.1.category }.sorted { $0.key < $1.key }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Ajouter un article", text: $newItem).padding(.horizontal, 14).frame(minHeight: 46).glass(16).foregroundStyle(P.text).submitLabel(.done).onSubmit(add)
                    Button(action: add) { Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(P.ink).frame(width: 46, height: 46).background(Circle().fill(P.butter)) }.buttonStyle(.plain).accessibilityLabel("Ajouter")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(quick.filter { q in !rows.contains { normalized($0.1.ingredient.name) == normalized(q) && !$0.1.checked } }, id: \.self) { q in
                            Button("+ \(q)") { store.put(.shopping(Shopping(ingredient: Ingredient(q, 1, .piece)))); if store.error == nil { store.toast = "\(q) ajouté" } }
                                .font(.system(size: 13)).foregroundStyle(P.text).padding(.horizontal, 12).frame(minHeight: 36)
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        }
                    }
                }
                if rows.isEmpty { Text("Liste vide. Préparez la semaine dans Repas : les ingrédients manquants arrivent ici tout seuls.").font(.system(size: 14)).foregroundStyle(P.mut) }
                ForEach(groups, id: \.key) { g in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(g.key).kicker().padding(.bottom, 2)
                        ForEach(g.value.sorted { (!$0.1.checked ? 0 : 1) < (!$1.1.checked ? 0 : 1) }, id: \.0.id) { item in
                            HStack(spacing: 6) {
                                CheckBox(on: item.1.checked, action: { withAnimation { store.toggleShopping(item.0) } }, label: item.1.ingredient.name)
                                Text(item.1.ingredient.name).font(.system(size: 15)).foregroundStyle(item.1.checked ? P.mut : P.text).strikethrough(item.1.checked)
                                Spacer()
                                if item.1.ingredient.unit != .piece || item.1.ingredient.quantity != 1 {
                                    Text("\(item.1.ingredient.quantity.formatted()) \(item.1.ingredient.unit.label)").font(.system(size: 12)).foregroundStyle(P.mut)
                                }
                                if item.1.generated { Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(P.lav).accessibilityLabel("Ajouté par DUO pour les repas") }
                            }
                        }
                    }.padding(14).glass(20)
                }
            }.padding(.bottom, 20)
        }.scrollIndicators(.hidden)
    }
    private func add() {
        let t = newItem.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
        store.put(.shopping(Shopping(ingredient: Ingredient(t, 1, .piece)))); if store.error == nil { newItem = "" }
    }
}

struct ChefV2: View {
    @Environment(AppStore.self) private var store
    @AppStorage("duo.chef.text") private var chefText = ""
    @State private var thinking = false
    var body: some View {
        let cal = Calendar.current
        let foods = store.foodRows.filter { $0.1.expiry != nil }.sorted { ($0.1.expiry ?? .distantFuture) < ($1.1.expiry ?? .distantFuture) }
        let tips = store.proposals.filter { ["expiry", "tonight", "week", "restock", "leftover"].contains($0.family) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text("Chef DUO").kicker().foregroundStyle(P.lav); Text("Le conseil du jour").font(P.serif(21)).foregroundStyle(P.text) }
                        Spacer()
                        Text(ChefAI.isAvailable ? "IA Apple · sur l'iPhone" : "Règles locales").font(.system(size: 11)).foregroundStyle(P.mut)
                    }
                    if !chefText.isEmpty { Text(chefText).font(.system(size: 15)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true) }
                    else if !ChefAI.isAvailable { Text("Active Apple Intelligence dans les Réglages de l'iPhone pour que le chef rédige ses conseils. En attendant, DUO te propose ci-dessous ses idées calculées.").font(.system(size: 13)).foregroundStyle(P.mut) }
                    if ChefAI.isAvailable {
                        Button(thinking ? "Le chef réfléchit…" : "Nouveau conseil") {
                            thinking = true
                            Task { if let t = await ChefAI.brief(context: store.chefContext) { chefText = t }; thinking = false }
                        }.font(.system(size: 13, weight: .semibold)).foregroundStyle(P.lav).disabled(thinking)
                    }
                }
                .padding(16).background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LinearGradient(colors: [P.lav.opacity(0.22), P.card.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.1)))

                ForEach(tips) { ProposalCardV2(p: $0).frame(maxWidth: .infinity) }

                Text("Au frigo").kicker()
                VStack(spacing: 0) {
                    if foods.isEmpty { Text("Ajoutez vos produits avec leur date pour que le chef évite le gaspillage.").font(.system(size: 14)).foregroundStyle(P.mut).frame(maxWidth: .infinity, alignment: .leading) }
                    ForEach(foods, id: \.0.id) { item in
                        let days = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: item.1.expiry ?? Date()).day ?? 0)
                        let color = days <= 2 ? P.peach : (days <= 5 ? P.butter : P.mint)
                        HStack(spacing: 12) {
                            Text(item.1.name).font(.system(size: 15)).foregroundStyle(P.text)
                            Spacer()
                            Capsule().fill(Color.white.opacity(0.08)).frame(width: 80, height: 6)
                                .overlay(alignment: .leading) { Capsule().fill(color).frame(width: max(8, 80 - CGFloat(min(days, 10)) * 7.2)) }
                            Text(days == 0 ? "auj." : "\(days) j").font(.system(size: 12)).foregroundStyle(color).frame(width: 40, alignment: .trailing)
                        }.frame(minHeight: 44)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 6).glass(20)
                NavigationLink { KitchenView().navigationTitle("Stock") } label: { Label("Gérer le frigo et les placards", systemImage: "refrigerator").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.lav).frame(minHeight: 44) }
            }.padding(.bottom, 20)
        }.scrollIndicators(.hidden)
    }
}
