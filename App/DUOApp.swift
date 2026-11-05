import SwiftUI
import DUOCore

// The first usable iPhone build is deliberately offline and single-device.
// Change this flag only when two-device sync has been tested and approved.
enum DUORelease {
    static let soloOnly = true
    // Stable frames let XCUITest wait for the app to become idle.
    // Normal users keep minute-by-minute live date/appearance updates.
    static let uiTesting = ProcessInfo.processInfo.arguments.contains("-duo-ui-test")
}

@main @MainActor struct DUOApp: App {
    @State private var store = AppStore()
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("nightStart") private var nightStart = 1200
    @AppStorage("nightEnd") private var nightEnd = 420
    var body: some Scene {
        WindowGroup {
            if DUORelease.uiTesting {
                RootView()
                    .environment(store)
                    .preferredColorScheme(.dark)
                    .tint(Color("Control"))
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    RootView()
                        .environment(store)
                        .preferredColorScheme(DuoTheme.scheme(mode: appearance, date: context.date, start: nightStart, end: nightEnd))
                        .tint(Color("Control"))
                }
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
            nav("Tâches") { HouseholdView() }.tabItem { Label("Tâches", systemImage: "checkmark.circle") }
            nav("Courses") { ShoppingView() }.tabItem { Label("Courses", systemImage: "basket") }
            nav("Planning") { PlanningView() }.tabItem { Label("Planning", systemImage: "calendar") }
            nav("Nous") { CoupleIdeasView() }.tabItem { Label("Nous", systemImage: "heart") }
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
        Group {
            if DUORelease.uiTesting {
                homeContent(date: Date())
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    homeContent(date: context.date)
                }
            }
        }
        .sheet(isPresented: $addTask) { NavigationStack { ItemEditor(kind: "task") } }
        .sheet(isPresented: $addShopping) { NavigationStack { ItemEditor(kind: "shopping") } }
        .sheet(isPresented: $addEvent) { NavigationStack { ItemEditor(kind: "event") } }
    }

    private func homeContent(date: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                welcome(date)

                    // Calm hierarchy: the next concrete action comes before dashboard metrics.
                    sectionHeading("Aujourd’hui", detail: "\(dueTasks(on: date).count) tâche(s)")
                    VStack(alignment: .leading, spacing: 0) {
                        if dueTasks(on: date).isEmpty {
                            emptyRow(pendingTasks.isEmpty ? "Commence par ajouter ta première tâche." : "Rien d’urgent. Profite de ce temps libre.", symbol: pendingTasks.isEmpty ? "sparkles" : "checkmark.seal")
                        }
                        ForEach(dueTasks(on: date).prefix(3)) { row in
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
                                            Text(due < date ? "En retard" : due.formatted(date: .omitted, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(due < date ? Color("Error") : Color("SecondaryReadable"))
                                        } else {
                                            Text("Sans échéance").font(.caption).foregroundStyle(Color("SecondaryReadable"))
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 5)
                                if row.id != dueTasks(on: date).prefix(3).last?.id {
                                    Divider().opacity(0.35)
                                }
                            }
                        }
                        NavigationLink { HouseholdView().navigationTitle("Tâches") } label: {
                            Label("Voir toutes mes tâches", systemImage: "arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 10)
                        }
                    }
                    .duoPanel()


                    NavigationLink { CoupleIdeasView().navigationTitle("Nous deux") } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title2)
                                .foregroundStyle(Color("Accent"))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Un moment à deux").font(.headline)
                                Text("3 idées nouvelles chaque jour, sans pression.")
                                    .font(.caption).foregroundStyle(Color("SecondaryReadable"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(Color("Text"))
                        .duoPanel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("openCoupleIdeas")

                    sectionHeading("Actions rapides", detail: "En un geste")
                    HStack(spacing: 10) {
                        quickAction("Tâche", symbol: "checkmark.circle.badge.plus") { addTask = true }
                            .accessibilityIdentifier("quickAddTask")
                        quickAction("Course", symbol: "basket.badge.plus") { addShopping = true }
                            .accessibilityIdentifier("quickAddShopping")
                        NavigationLink { KitchenView().navigationTitle("Cuisine") } label: {
                            quickActionAppearance("Cuisine", symbol: "fork.knife")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("openKitchen")
                        quickAction("RDV", symbol: "calendar.badge.plus") { addEvent = true }
                    }

                    HStack(spacing: 18) {
                        Label("\(pendingTasks.count) tâche(s) ouverte(s)", systemImage: "checkmark.circle")
                        Label("\(pendingShopping.count) à acheter", systemImage: "basket")
                    }
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryReadable"))
                    .accessibilityElement(children: .combine)

                    if !todaysEvents(on: date).isEmpty || !todaysMeals(on: date).isEmpty {
                        sectionHeading("Mon programme", detail: "Aujourd’hui")
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(todaysEvents(on: date).prefix(2)) { row in
                                if case .event(let event) = row.payload {
                                    Label(event.start.formatted(date: .omitted, time: .shortened) + " · " + event.title,
                                          systemImage: event.sport ? "figure.run" : "calendar")
                                        .font(.subheadline)
                                }
                            }
                            ForEach(todaysMeals(on: date).prefix(1)) { row in
                                if case .meal(let meal) = row.payload,
                                   let recipe = Catalog.recipes.first(where: { $0.id == meal.recipeID }) {
                                    Label(recipe.title, systemImage: "fork.knife")
                                        .font(.subheadline)
                                }
                            }
                            NavigationLink { PlanningView().navigationTitle("Planning") } label: {
                                Label("Ouvrir mon planning", systemImage: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.top, 4)
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
                        $0.expiry! < date.addingTimeInterval(3 * 86400)
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

    private func sectionHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold()).foregroundStyle(Color("Text"))
            Spacer()
            Text(detail).font(.caption).foregroundStyle(Color("SecondaryReadable"))
        }
    }

    private func quickAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { quickActionAppearance(title, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func quickActionAppearance(_ title: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color("Accent"))
                .frame(height: 26)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("Text"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 12)
        .background(Color("Surface").opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color("Ice").opacity(0.25), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func emptyRow(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(Color("SecondaryReadable"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private struct CoupleIdea {
    let title: String
    let detail: String
    let minutes: Int
    let symbol: String
    let category: String
}

struct CoupleIdeasView: View {
    @AppStorage("duo.couple.completedDay") private var completedDay = ""
    @AppStorage("duo.couple.completedIndices") private var completedIndices = ""
    @State private var selectedDate = Date()

    // Curated, offline, free suggestions: no accounts, analytics or personal data.
    private let ideas: [CoupleIdea] = [
        .init(title: "Le meilleur moment", detail: "Racontez chacun le meilleur moment de votre journée et pourquoi il vous a marqué.", minutes: 5, symbol: "sun.max", category: "Connexion"),
        .init(title: "Une gratitude précise", detail: "Remerciez l'autre pour un geste concret de cette semaine.", minutes: 5, symbol: "heart", category: "Bienveillance"),
        .init(title: "Balade sans écran", detail: "Marchez ensemble, téléphones rangés, et choisissez chacun une question à poser.", minutes: 20, symbol: "figure.walk", category: "Sortie"),
        .init(title: "Cuisiner à quatre mains", detail: "Préparez un repas simple ensemble en vous répartissant les étapes.", minutes: 30, symbol: "fork.knife", category: "À la maison"),
        .init(title: "Notre prochain mini-rêve", detail: "Imaginez une activité réalisable ce mois-ci, avec un budget choisi ensemble.", minutes: 15, symbol: "sparkles", category: "Projets"),
        .init(title: "La question inattendue", detail: "Quel endroit aimerais-tu me faire découvrir, et pourquoi ?", minutes: 10, symbol: "questionmark.bubble", category: "Discussion"),
        .init(title: "Une chanson, une histoire", detail: "Écoutez chacun une chanson et racontez le souvenir qu'elle évoque.", minutes: 15, symbol: "music.note", category: "Découverte"),
        .init(title: "Un vrai compliment", detail: "Dites chacun une qualité que vous admirez chez l'autre, avec un exemple.", minutes: 5, symbol: "star", category: "Bienveillance"),
        .init(title: "Un petit service", detail: "Demandez : « Qu'est-ce qui te soulagerait aujourd'hui ? » Puis choisissez un geste réalisable.", minutes: 10, symbol: "hands.sparkles", category: "Entraide"),
        .init(title: "Soirée jeux express", detail: "Choisissez un jeu de cartes ou de société et jouez sans chercher à gagner à tout prix.", minutes: 25, symbol: "gamecontroller", category: "Détente"),
        .init(title: "Le souvenir préféré", detail: "Racontez votre souvenir préféré ensemble et ce que vous aimeriez revivre.", minutes: 10, symbol: "photo", category: "Connexion"),
        .init(title: "Le rendez-vous gratuit", detail: "Organisez un petit rendez-vous sans achat : coucher de soleil, pique-nique maison ou promenade.", minutes: 20, symbol: "leaf", category: "Sortie"),
        .init(title: "Écouter sans réparer", detail: "Pendant cinq minutes chacun, écoutez sans interrompre ni proposer de solution, sauf demande.", minutes: 10, symbol: "ear", category: "Communication"),
        .init(title: "Notre recette signature", detail: "Inventez un nom pour un plat que vous aimez et planifiez quand le refaire.", minutes: 10, symbol: "birthday.cake", category: "À la maison"),
        .init(title: "La boîte à idées", detail: "Notez chacun trois activités à faire à deux, puis choisissez-en une.", minutes: 15, symbol: "tray.full", category: "Projets"),
        .init(title: "Une photo du quotidien", detail: "Prenez une photo d'un moment ordinaire que vous aurez plaisir à revoir.", minutes: 5, symbol: "camera", category: "Souvenirs"),
        .init(title: "Ce qui me rassure", detail: "Partagez chacun une petite attention qui vous fait vous sentir soutenu.", minutes: 10, symbol: "shield.lefthalf.filled", category: "Communication"),
        .init(title: "Découverte à l'aveugle", detail: "Faites goûter à l'autre trois aliments familiers, en respectant ses préférences.", minutes: 15, symbol: "carrot", category: "Jeu"),
        .init(title: "Notre dimanche idéal", detail: "Décrivez votre dimanche parfait, puis trouvez un élément simple à réaliser.", minutes: 10, symbol: "calendar", category: "Projets"),
        .init(title: "Mini-défi créatif", detail: "Dessinez chacun l'autre en deux minutes et échangez vos œuvres avec humour.", minutes: 10, symbol: "pencil.tip", category: "Jeu"),
        .init(title: "Un point positif", detail: "Dites ce qui fonctionne bien dans votre quotidien à deux et que vous souhaitez préserver.", minutes: 10, symbol: "checkmark.seal", category: "Communication"),
        .init(title: "Pause douceur", detail: "Prenez un thé ou une boisson ensemble, sans écran, sans obligation de parler.", minutes: 15, symbol: "cup.and.saucer", category: "Détente"),
        .init(title: "Notre liste de découvertes", detail: "Choisissez un lieu proche à visiter et une date possible, sans engagement.", minutes: 10, symbol: "map", category: "Sortie"),
        .init(title: "Apprendre quelque chose", detail: "Montrez à l'autre une petite compétence ou une astuce que vous aimez.", minutes: 15, symbol: "lightbulb", category: "Découverte"),
        .init(title: "Une question sur l'enfance", detail: "Quel jeu ou rituel aimais-tu particulièrement quand tu étais petit ?", minutes: 10, symbol: "bubble.left.and.bubble.right", category: "Discussion"),
        .init(title: "Le partage des tâches", detail: "Choisissez une tâche qui pèse sur l'un de vous et trouvez une répartition plus confortable.", minutes: 10, symbol: "checklist", category: "Entraide"),
        .init(title: "Notre petit rituel", detail: "Inventez un rituel de deux minutes qui vous ferait plaisir chaque semaine.", minutes: 10, symbol: "heart.circle", category: "Connexion"),
        .init(title: "Le bilan sans jugement", detail: "Chacun partage une chose appréciée cette semaine et une petite amélioration souhaitée.", minutes: 15, symbol: "person.2", category: "Communication")
    ]

    private var dayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    private var dayNumber: Int {
        Calendar.current.ordinality(of: .day, in: .era, for: selectedDate) ?? 0
    }
    private var todaysIndices: [Int] {
        let base = (dayNumber * 3) % ideas.count
        return (0..<3).map { (base + $0) % ideas.count }
    }
    private var done: Set<Int> {
        guard completedDay == dayKey else { return [] }
        return Set(completedIndices.split(separator: ",").compactMap { Int($0) })
    }
    private func toggle(_ index: Int) {
        var updated = done
        if updated.contains(index) { updated.remove(index) } else { updated.insert(index) }
        completedDay = dayKey
        completedIndices = updated.sorted().map(String.init).joined(separator: ",")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("NOTRE MOMENT", systemImage: "heart.fill")
                        .font(.caption.bold()).foregroundStyle(Color("Accent"))
                    Text("Des idées pour nous deux").font(.title2.bold())
                    Text("Trois propositions par jour. Choisissez ce qui vous fait envie, sans obligation.")
                        .font(.subheadline).foregroundStyle(Color("SecondaryReadable"))
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.caption).foregroundStyle(Color("SecondaryReadable"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoPanel()

                ForEach(todaysIndices, id: \.self) { index in
                    let idea = ideas[index]
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(idea.category, systemImage: idea.symbol)
                                .font(.caption.weight(.semibold)).foregroundStyle(Color("Accent"))
                            Spacer()
                            Label("\(idea.minutes) min", systemImage: "clock")
                                .font(.caption).foregroundStyle(Color("SecondaryReadable"))
                        }
                        Text(idea.title).font(.headline)
                        Text(idea.detail).font(.subheadline)
                            .foregroundStyle(Color("SecondaryReadable"))
                        Button {
                            toggle(index)
                        } label: {
                            Label(done.contains(index) ? "Fait ensemble" : "On l'a fait !",
                                  systemImage: done.contains(index) ? "checkmark.circle.fill" : "circle")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("coupleIdeaToggle\(index)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .duoPanel()
                }
                Text("Les idées changent chaque jour sur cet iPhone. Vos choix restent privés et locaux.")
                    .font(.caption).foregroundStyle(Color("SecondaryReadable"))
            }
            .padding(18)
        }
        .background(Color("Background"))
        .navigationTitle("Nous deux")
        .onAppear { selectedDate = Date() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            selectedDate = Date()
        }
        .accessibilityIdentifier("coupleIdeasScreen")
    }
}
