import SwiftUI
import DUOCore

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
            nav("Vie commune") { HouseholdView() }.tabItem { Label("Vie commune", systemImage: "person.2") }
        }
        .disabled(store.syncing || !store.ready)
        .overlay { if store.syncing { ProgressView("Synchronisation…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $assistant) { NavigationStack { AssistantView() } }
        .onOpenURL { url in store.receiveInviteURL(url); if store.pendingInvitation != nil { settings = true } }
        .alert("DUO", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Compris") { store.error = nil } } message: { Text(store.error ?? "") }
        .task { await store.restoreSessionIfAvailable(); while !Task.isCancelled { try? await Task.sleep(for: .seconds(30)); if phase == .active { await store.sync(showErrors: false) } } }
        .onChange(of: phase) { _, next in if next == .active { Task { await store.sync(showErrors: false) } } }
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
    @AppStorage("homePriority") private var priority = "auto"
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hour = Calendar.current.component(.hour, from: context.date)
            let period = priority == "auto" ? (hour < 12 ? "Matin" : hour < 18 ? "Après-midi" : "Soir") : priority
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).foregroundStyle(Color("SecondaryReadable"))
                    Text(hour < 18 ? "Un peu d’organisation.\nDu temps pour vous." : "On se retrouve\nà la maison.").font(.largeTitle.bold()).foregroundStyle(Color("Text"))
                    if period == "Matin" { today(context.date) }
                    if period == "Après-midi" { NavigationLink { ShoppingView() } label: { Label("Préparer les courses", systemImage: "basket").frame(maxWidth: .infinity, alignment: .leading).duoPanel() } }
                    if let recipe = store.suggestions.first {
                        NavigationLink { RecipeView(recipe: recipe) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Une idée pour ce soir", systemImage: "sparkles").font(.subheadline)
                                Text(recipe.title).font(.title2.bold())
                                Text("\(recipe.preparation + recipe.cooking) min · pour \(recipe.portions)").font(.subheadline)
                            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Color("Text")).duoPanel()
                        }
                    }
                    if period != "Matin" { today(context.date) }
                    let expiring = store.foods.filter { $0.quantity > 0 && $0.expiry != nil && $0.expiry! < context.date.addingTimeInterval(3 * 86400) }
                    if !expiring.isEmpty { Label("À vérifier bientôt : " + expiring.map(\.name).joined(separator: ", "), systemImage: "clock.badge.exclamationmark").foregroundStyle(Color("Text")) }
                    if period == "Soir", let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: context.date) { Text("Demain").font(.headline); eventSummary(tomorrow) }
                    Text(store.status).font(.caption).foregroundStyle(Color("SecondaryReadable"))
                }.padding(20)
            }.background(Color("Background"))
        }
    }
    @ViewBuilder private func today(_ date: Date) -> some View {
        Text("Aujourd’hui").font(.title3.bold()); eventSummary(date)
        ForEach(store.records.filter { if case .task(let t) = $0.payload { return t.completed == nil && (t.due == nil || t.due! <= Calendar.current.startOfDay(for: date).addingTimeInterval(86400)) }; return false }.prefix(3)) { row in
            if case .task(let t) = row.payload { Button { store.toggle(row) } label: { Label(t.title, systemImage: "circle").frame(minHeight: 44) } }
        }
    }
    @ViewBuilder private func eventSummary(_ date: Date) -> some View {
        let events = store.records.filter { if case .event(let e) = $0.payload { return Calendar.current.isDate(e.start, inSameDayAs: date) }; return false }
        if events.isEmpty { Text("De la place pour vos envies.").foregroundStyle(Color("SecondaryReadable")) }
        ForEach(events) { row in if case .event(let e) = row.payload { Label(e.start.formatted(date: .omitted, time: .shortened) + " · " + e.title, systemImage: e.sport ? "figure.run" : "calendar") } }
    }
}
