import SwiftUI
import DUOCore

// The first usable iPhone build is deliberately offline and single-device.
// Change this flag only when two-device sync has been tested and approved.
enum DUORelease {
    static let soloOnly = true
}

@main @MainActor struct DUOApp: App {
    @State private var store = AppStore()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("nightStart") private var nightStart = 1200
    @AppStorage("nightEnd") private var nightEnd = 420
    var body: some Scene {
        WindowGroup {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                RootView().environment(store)
                    .preferredColorScheme(DuoTheme.scheme(mode: appearance, date: context.date, start: nightStart, end: nightEnd))
                    .tint(Color("Control"))
            }
        }
    }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var settings = false
    @State private var assistant = false
    var body: some View {
        @Bindable var store = store
        TabView {
            nav("Accueil") { HomeView() }.tabItem { Label("Accueil", systemImage: "house") }
            nav("Cuisine") { KitchenView() }.tabItem { Label("Cuisine", systemImage: "fork.knife") }
            nav("Courses") { ShoppingView() }.tabItem { Label("Courses", systemImage: "basket") }
            nav("Planning") { PlanningView() }.tabItem { Label("Planning", systemImage: "calendar") }
            nav("Tâches") { HouseholdView() }.tabItem { Label("Tâches", systemImage: "checkmark.circle") }
        }
        .disabled(store.syncing || !store.ready)
        .overlay { if store.syncing { ProgressView("Synchronisation…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $assistant) { NavigationStack { AssistantView() } }
        .onOpenURL { url in
            guard !DUORelease.soloOnly else { return }
            store.receiveInviteURL(url)
            if store.pendingInvitation != nil { settings = true }
        }
        .alert("DUO", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Compris") { store.error = nil } } message: { Text(store.error ?? "") }
        .task {
            // In solo mode the app never authenticates or synchronises in the background.
            guard !DUORelease.soloOnly else { return }
            await store.restoreSessionIfAvailable()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled else { return }
                if phase == .active { await store.sync(showErrors: false) }
            }
        }
        .onChange(of: phase) { _, next in
            if !DUORelease.soloOnly && next == .active {
                Task { await store.sync(showErrors: false) }
            }
        }
    }
    private func nav<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        NavigationStack { content().navigationTitle(title).toolbar { ToolbarItemGroup(placement: .topBarTrailing) {
            Button { assistant = true } label: { Image(systemName: "sparkles") }.accessibilityLabel("Parler à Joe")
            Button { settings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Réglages")
        } } }
    }
}
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var addTask = false
    @State private var addShopping = false
    @State private var addFood = false
    @State private var addEvent = false

    private var pendingTasks: [Record] {
        store.records.filter {
            if case .task(let task) = $0.payload { return task.completed == nil }
            return false
        }
    }

    private var pendingShopping: [Record] {
        store.records.filter {
            if case .shopping(let item) = $0.payload { return !item.checked }
            return false
        }
    }

    private func dueTasks(on date: Date) -> [Record] {
        let endOfDay = Calendar.current.startOfDay(for: date).addingTimeInterval(86400)
        return pendingTasks.filter { row in
            guard case .task(let task) = row.payload else { return false }
            return task.due == nil || task.due! < endOfDay
        }.sorted { a, b in
            guard case .task(let first) = a.payload,
                  case .task(let second) = b.payload else { return false }
            return (first.due ?? .distantFuture) < (second.due ?? .distantFuture)
        }
    }

    private func todaysEvents(on date: Date) -> [Record] {
        store.records.filter { row in
            guard case .event(let event) = row.payload else { return false }
            return Calendar.current.isDate(event.start, inSameDayAs: date)
        }.sorted { a, b in
            guard case .event(let first) = a.payload,
                  case .event(let second) = b.payload else { return false }
            return first.start < second.start
        }
    }

    private func todaysMeals(on date: Date) -> [Record] {
        store.records.filter { row in
            guard case .meal(let meal) = row.payload else { return false }
            return !meal.cooked && Calendar.current.isDate(meal.date, inSameDayAs: date)
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    welcome(context.date)
                    HStack(spacing: 12) {
                        statTile("\(pendingTasks.count)", label: "Tâches ouvertes", symbol: "checkmark.circle")
                        statTile("\(pendingShopping.count)", label: "À acheter", symbol: "basket")
                    }
                    sectionHeading("Un geste, c’est fait", detail: "Vos raccourcis")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        quickAction("Une tâche", symbol: "checkmark.circle.badge.plus") { addTask = true }
                        quickAction("Une course", symbol: "basket.badge.plus") { addShopping = true }
                        quickAction("Un aliment", symbol: "carrot") { addFood = true }
                        quickAction("Un rendez-vous", symbol: "calendar.badge.plus") { addEvent = true }
                    }

                    sectionHeading("À faire aujourd’hui", detail: "\(dueTasks(on: context.date).count) à voir")
                    VStack(alignment: .leading, spacing: 0) {
                        if dueTasks(on: context.date).isEmpty {
                            emptyRow("Rien d’urgent. Profitez de ce temps libre.", symbol: "checkmark.seal")
                        }
                        ForEach(dueTasks(on: context.date).prefix(4)) { row in
                            if case .task(let task) = row.payload {
                                HStack(spacing: 14) {
                                    Button { store.toggle(row) } label: {
                                        Image(systemName: "circle")
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Terminer \(task.title)")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title).font(.body.weight(.medium))
                                        if let due = task.due {
                                            Text(due < context.date ? "En retard" : due.formatted(date: .omitted, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(due < context.date ? Color("Error") : Color("SecondaryReadable"))
                                        } else {
                                            Text("Sans échéance").font(.caption).foregroundStyle(Color("SecondaryReadable"))
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                                if row.id != dueTasks(on: context.date).prefix(4).last?.id {
                                    Divider().opacity(0.35)
                                }
                            }
                        }
                        NavigationLink { HouseholdView() } label: {
                            Label("Voir toutes mes tâches", systemImage: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 10)
                        }
                    }
                    .duoPanel()

                    if !todaysEvents(on: context.date).isEmpty || !todaysMeals(on: context.date).isEmpty {
                        sectionHeading("Mon programme", detail: "Aujourd’hui")
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(todaysEvents(on: context.date)) { row in
                                if case .event(let event) = row.payload {
                                    Label(event.start.formatted(date: .omitted, time: .shortened) + " · " + event.title,
                                          systemImage: event.sport ? "figure.run" : "calendar")
                                        .font(.subheadline)
                                }
                            }
                            ForEach(todaysMeals(on: context.date)) { row in
                                if case .meal(let meal) = row.payload,
                                   let recipe = Catalog.recipes.first(where: { $0.id == meal.recipeID }) {
                                    Label(recipe.title, systemImage: "fork.knife")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .duoPanel()
                    }

                    if let recipe = store.suggestions.first {
                        sectionHeading("Une idée pour ce soir", detail: "Selon votre cuisine")
                        NavigationLink { RecipeView(recipe: recipe) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color("Accent"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.title).font(.headline)
                                    Text("\(recipe.preparation + recipe.cooking) min · \(recipe.portions) portions")
                                        .font(.caption).foregroundStyle(Color("SecondaryReadable"))
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.bold())
                            }
                            .foregroundStyle(Color("Text"))
                            .duoPanel()
                        }
                        .buttonStyle(.plain)
                    }

                    let expiring = store.foods.filter {
                        $0.quantity > 0 && $0.expiry != nil &&
                        $0.expiry! < context.date.addingTimeInterval(3 * 86400)
                    }
                    if !expiring.isEmpty {
                        Label("À vérifier : " + expiring.map(\.name).joined(separator: ", "),
                              systemImage: "clock.badge.exclamationmark")
                            .font(.subheadline)
                            .foregroundStyle(Color("Error"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .duoPanel()
                    }

                    Label("Données enregistrées sur cet iPhone", systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryReadable"))
                        .frame(maxWidth: .infinity)
                }
                .padding(18)
            }
            .background(Color("Background"))
        }
        .sheet(isPresented: $addTask) { NavigationStack { ItemEditor(kind: "task") } }
        .sheet(isPresented: $addShopping) { NavigationStack { ItemEditor(kind: "shopping") } }
        .sheet(isPresented: $addFood) { NavigationStack { ItemEditor(kind: "food") } }
        .sheet(isPresented: $addEvent) { NavigationStack { ItemEditor(kind: "event") } }
    }

    private func welcome(_ date: Date) -> some View {
        let hour = Calendar.current.component(.hour, from: date)
        let greeting = hour < 12 ? "Bonjour" : hour < 18 ? "Bon après-midi" : "Bonsoir"
        return VStack(alignment: .leading, spacing: 12) {
            Label("DUO  ·  MON ESPACE", systemImage: "sparkle")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color("Accent"))
            Text(greeting + " !")
                .font(.largeTitle.bold())
                .foregroundStyle(Color("Text"))
            Text("Un quotidien plus simple, une chose à la fois.")
                .font(.subheadline)
                .foregroundStyle(Color("SecondaryReadable"))
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color("Text"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(colors: [Color("Surface"), Color("Ice").opacity(0.24)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
        )
    }

    private func statTile(_ number: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Color("Accent"))
            Text(number).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Color("SecondaryReadable"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color("Text"))
        .duoPanel()
        .accessibilityElement(children: .combine)
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold()).foregroundStyle(Color("Text"))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(Color("SecondaryReadable"))
        }
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(Color("Accent"))
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color("Text"))
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .duoPanel()
        }
        .buttonStyle(.plain)
    }

    private func emptyRow(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(Color("SecondaryReadable"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
