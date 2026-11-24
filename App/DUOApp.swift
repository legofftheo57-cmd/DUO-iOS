import SwiftUI
import DUOCore

// The first usable iPhone build is deliberately offline and single-device.
// Change this flag only when two-device sync has been tested and approved.
enum DUORelease {
    /// Mode foyer automatique dès qu'un serveur Supabase est intégré à la compilation.
    static let soloOnly: Bool = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              raw.hasPrefix("https://"), raw.contains(".supabase.co") else { return true }
        return false
    }()
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
                        .preferredColorScheme(.dark) // Nouvelle interface « nuit et pastels »
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
        RootV2(settings: $settings, assistant: $assistant)
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
        let endOfDay = Calendar.current.dateInterval(of: .day, for: date)?.end ?? date
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


                    NavigationLink { BudgetView().navigationTitle("Budget") } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("Accent"))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notre budget").font(.headline)
                                Text("Salaires, dépenses et épargne, en toute simplicité.")
                                    .font(.caption)
                                    .foregroundStyle(Color("SecondaryReadable"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .foregroundStyle(Color("Text"))
                        .duoPanel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("openBudget")

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
    @Environment(AppStore.self) private var store
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

    private var dayKey: String { CoupleSchedule.dayKey(selectedDate) }
    private var todaysIndices: [Int] { CoupleSchedule.indices(on: selectedDate, count: ideas.count) }
    private var done: Set<Int> {
        store.snapshot.coupleDay == dayKey ? Set(store.snapshot.coupleCompleted ?? []) : []
    }
    private func toggle(_ index: Int) {
        // Resolve the real day at the tap, even across a midnight boundary.
        selectedDate = Date()
        guard todaysIndices.contains(index) else { return }
        store.transact { snapshot in
            var updated = snapshot.coupleDay == dayKey ? Set(snapshot.coupleCompleted ?? []) : []
            if updated.contains(index) { updated.remove(index) } else { updated.insert(index) }
            snapshot.coupleDay = dayKey
            snapshot.coupleCompleted = updated.sorted()
        }
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
                        ViewThatFits(in: .horizontal) {
                          HStack {
                            Label(idea.category, systemImage: idea.symbol)
                                .font(.caption.weight(.semibold)).foregroundStyle(Color("Accent"))
                            Spacer()
                            Label("\(idea.minutes) min", systemImage: "clock")
                                .font(.caption).foregroundStyle(Color("SecondaryReadable"))
                        }
                          VStack(alignment: .leading, spacing: 6) {
                            Label(idea.category, systemImage: idea.symbol)
                            Label("\(idea.minutes) min", systemImage: "clock")
                          }.font(.caption).foregroundStyle(Color("Accent"))
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
                        .accessibilityValue(done.contains(index) ? "Terminée" : "À découvrir")
                        .accessibilityHint(done.contains(index) ? "Touchez pour annuler la validation" : "Valider cette activité ensemble")
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            selectedDate = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            selectedDate = Date()
        }
        .accessibilityIdentifier("coupleIdeasScreen")
    }
}


// MARK: - Budget local privé (première étape, sans synchronisation bancaire)

enum BudgetDisk {
    private static func url() throws -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("budget-v1.json")
    }

    static func load() throws -> [BudgetEntry] {
        let file = try url()
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([BudgetEntry].self, from: Data(contentsOf: file))
    }

    static func save(_ entries: [BudgetEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        // Protected local file: no bank credentials, analytics, or remote transmission.
        try data.write(to: url(), options: [.atomic, .completeFileProtection])
    }
}

struct BudgetView: View {
    @Environment(AppStore.self) private var store
    private var entries: [BudgetEntry] { store.snapshot.manualBudget ?? [] }
    @State private var editingID: UUID?
    @State private var selectedMonth = Date()
    @State private var adding = false
    @State private var kind: BudgetKind = .expense
    @State private var amount = ""
    @State private var person = "Théo"
    @State private var shared = true
    @State private var category = "Courses"
    @State private var note = ""
    @State private var transactionDate = Date()
    @State private var error: String?

    private var monthEntries: [BudgetEntry] {
        entries.filter { Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private func total(_ kind: BudgetKind) -> Int {
        monthEntries.filter { $0.kind == kind }.reduce(0) { $0 + $1.cents }
    }

    private var sharedExpenses: Int {
        monthEntries.filter { $0.kind == .expense && $0.shared }.reduce(0) { $0 + $1.cents }
    }

    private var personalExpenses: Int {
        monthEntries.filter { $0.kind == .expense && !$0.shared }.reduce(0) { $0 + $1.cents }
    }

    private var remaining: Int { total(.income) - total(.expense) - total(.savings) }

    private var categories: [String] {
        switch kind {
        case .income: return ["Salaire", "Prime", "Remboursement", "Autre revenu"]
        case .expense: return ["Courses", "Loyer", "Transport", "Factures", "Abonnements", "Santé", "Loisirs", "Autre"]
        case .savings: return ["Épargne de précaution", "Investissement", "Autre épargne"]
        }
    }

    var body: some View {
        List {
            Section {
                if let warning = store.budgetImportError { Text(warning).foregroundStyle(Color("Error")) }
                DatePicker("Mois à consulter", selection: $selectedMonth, displayedComponents: .date)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reste du budget saisi")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryReadable"))
                    Text(euros(remaining))
                        .font(.largeTitle.bold())
                        .foregroundStyle(remaining < 0 ? Color("Error") : Color("Text"))
                        .accessibilityIdentifier("budgetRemaining")
                    Text("Revenus saisis − dépenses − versements d’épargne. Ce calcul n’est pas un solde bancaire.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryReadable"))
                }
                .padding(.vertical, 8)
                HStack {
                    summary("Revenus", cents: total(.income), symbol: "arrow.down.left")
                    Spacer(minLength: 6)
                    summary("Dépenses", cents: total(.expense), symbol: "arrow.up.right")
                    Spacer(minLength: 6)
                    summary("Épargne", cents: total(.savings), symbol: "shield")
                }
            } header: { Text("Vue mensuelle") }

            Section {
                NavigationLink { ManualAccountsView() } label: { Label("Mes soldes manuels datés", systemImage: "building.columns") }
                Text("Comptes, épargne, placements et CET restent séparés du budget mensuel. Aucun solde n’est déduit automatiquement des opérations saisies.").font(.caption)
            }
            Section("Vie commune") {
                LabeledContent("Dépenses communes", value: euros(sharedExpenses))
                LabeledContent("Dépenses personnelles", value: euros(personalExpenses))
                Text("Les dépenses communes sont identifiées, sans calcul automatique de remboursement : votre règle de partage reste à choisir ensemble.")
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryReadable"))
            }

            Section("Opérations") {
                if monthEntries.isEmpty {
                    ContentUnavailableView("Aucune opération",
                                           systemImage: "eurosign.circle",
                                           description: Text("Ajoutez vos revenus, dépenses et versements d’épargne."))
                }
                ForEach(monthEntries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.kind == .income ? "arrow.down.left.circle" :
                              entry.kind == .savings ? "shield.lefthalf.filled" : "arrow.up.right.circle")
                            .foregroundStyle(Color("Accent"))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title).font(.subheadline.weight(.semibold))
                            Text("\(entry.person) · \(entry.shared ? "Commun" : "Personnel") · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryReadable"))
                        }
                        Spacer(minLength: 4)
                        Text((entry.kind == .income ? "+" : "−") + euros(entry.cents))
                            .font(.subheadline.monospacedDigit())
                    }
                    .swipeActions {
                        Button("Supprimer", role: .destructive) { remove(entry.id) }
                        Button("Modifier") { edit(entry) }.tint(Color("Accent"))
                    }
                }
            }

            Section {
                Label("Enregistré uniquement sur cet iPhone. Pas de connexion bancaire ni de partage automatique entre vos deux téléphones.", systemImage: "lock.iphone")
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryReadable"))
                Text("Le CET différé en brut n'est pas de l'argent disponible : ne l'ajoutez pas aux revenus ou à l'épargne versée.")
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryReadable"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingID = nil; amount = ""; note = ""; transactionDate = Date(); adding = true } label: { Image(systemName: "plus.circle.fill") }
                    .accessibilityLabel("Ajouter une opération")
                    .accessibilityIdentifier("addBudgetEntry")
                    .disabled(store.budgetImportError != nil)
            }
        }
        .sheet(isPresented: $adding) { entryForm }
        .alert("Budget", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Compris") { error = nil }
        } message: { Text(error ?? "") }

    }

    private func summary(_ title: String, cents: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(Color("SecondaryReadable"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(euros(cents))
                .font(.subheadline.bold().monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    private var entryForm: some View {
        NavigationStack {
            Form {
                Section("Opération") {
                    Picker("Type", selection: $kind) {
                        ForEach(BudgetKind.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.self) { item in Text(item).tag(item) }
                    }
                    TextField("Montant en € (ex. 42,50)", text: $amount)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("budgetAmount")
                    TextField("Note facultative", text: $note)
                    DatePicker("Date", selection: $transactionDate, in: ...Date(), displayedComponents: .date)
                }
                Section("Qui est concerné ?") {
                    Picker("Personne", selection: $person) {
                        Text("Théo").tag("Théo")
                        Text("Lilou").tag("Lilou")
                    }
                    if kind == .expense {
                        Toggle("Dépense commune", isOn: $shared)
                    }
                }
                Section {
                    Text("Saisie manuelle des opérations déjà effectuées, sans accès bancaire. Un virement entre comptes courants n’est ni un revenu ni une dépense. Pour l’épargne, indiquez le versement une seule fois.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryReadable"))
                }
            }
            .navigationTitle(editingID == nil ? "Nouvelle opération" : "Modifier l’opération")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { adding = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { add() }
                        .disabled(amountInCents(amount) == nil)
                        .accessibilityIdentifier("saveBudgetEntry")
                }
            }
            .onChange(of: kind) { _, _ in if !categories.contains(category) { category = categories[0] } }
        }
    }

    private func add() {
        guard let cents = amountInCents(amount) else {
            error = "Indiquez un montant positif avec deux décimales maximum."
            return
        }
        let trimmed = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let title = trimmed.isEmpty ? category : category + " · " + trimmed
        let item = BudgetEntry(id: editingID ?? UUID(), date: transactionDate, kind: kind, cents: cents,
                               title: title, person: person, shared: kind == .expense && shared)
        let updated = entries.filter { $0.id != item.id } + [item]
        do {
            try save(updated)
            adding = false
            amount = ""
            note = ""
            transactionDate = Date()
        } catch {
            self.error = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    private func remove(_ id: UUID) {
        let updated = entries.filter { $0.id != id }
        do {
            try save(updated)
        } catch {
            self.error = "Suppression impossible : \(error.localizedDescription)"
        }
    }

    private func euros(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR")))
    }

    private func amountInCents(_ input: String) -> Int? { ManualBudget.amountInCents(input) }
    private func save(_ updated: [BudgetEntry]) throws {
        try ManualBudget.validate(updated)
        store.transact { $0.manualBudget = updated }
        if let error = store.error { throw DuoError.invalid(error) }
    }
    private func edit(_ entry: BudgetEntry) {
        editingID = entry.id; kind = entry.kind
        amount = String(format: "%d.%02d", entry.cents / 100, entry.cents % 100)
        person = entry.person; shared = entry.shared; transactionDate = entry.date
        category = categories.first(where: { entry.title == $0 || entry.title.hasPrefix($0 + " · ") }) ?? categories[0]
        note = entry.title == category ? "" : entry.title.replacingOccurrences(of: category + " · ", with: "")
        adding = true
    }
}

struct ManualAccountsView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    @State private var accountID = UUID()
    @State private var name = ""
    @State private var kind = FinancialAccountType.checking
    @State private var amount = ""
    @State private var overdraft = false
    @State private var observed = Date()
    private var accounts: [ManualFinancialAccount] { store.snapshot.manualAccounts ?? [] }
    private let kinds: [FinancialAccountType] = [.checking, .savings, .investment, .deferredGrossCET]
    private func label(_ kind: FinancialAccountType) -> String {
        switch kind { case .checking: return "Compte courant"; case .savings: return "Épargne bancaire"; case .investment: return "Investissement"; case .deferredGrossCET: return "CET brut différé"; case .debt: return "Dette" }
    }
    private func money(_ cents: Int64) -> String { (Double(cents) / 100).formatted(.currency(code: "EUR")) }
    private var summary: FinanceLedgerSummary? {
        try? FinanceLedger.summarize(accounts: accounts.map { $0.ledgerSnapshot(owner: store.snapshot.userID) }, transactions: [], allocations: [], now: Date(), includeManualBalances: true)
    }
    var body: some View {
        List {
            Section {
                Text("Soldes saisis manuellement, à vérifier dans vos banques. Aucune connexion bancaire. Ces données restent sur cet iPhone et dans vos exports locaux.").font(.caption)
                if let summary {
                    LabeledContent("Comptes courants", value: money(summary.checkingCents))
                    LabeledContent("Épargne bancaire", value: money(summary.savingsCents))
                    LabeledContent("Investissements", value: money(summary.investmentsCents))
                    LabeledContent("CET brut différé", value: money(summary.deferredCETGrossCents))
                    Text("Le CET et les placements ne sont pas de l’argent disponible aujourd’hui. Un virement entre vos comptes ne crée pas de revenu.").font(.caption)
                }
            }
            Section("Comptes enregistrés") {
                ForEach(accounts) { account in
                    Button {
                        accountID = account.id; name = account.name; kind = account.type
                        amount = String(format: "%.2f", Double(abs(account.cents)) / 100)
                        overdraft = account.cents < 0; observed = account.observedAt; editing = true
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(account.name).font(.headline)
                            Text(label(account.type) + " · " + money(account.cents))
                            Text("Manuel · relevé le " + account.observedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                            if summary?.staleAccountIDs.contains(account.id.uuidString) == true {
                                Label("À actualiser", systemImage: "clock").font(.caption)
                            }
                        }
                    }.swipeActions { Button("Supprimer", role: .destructive) { save(accounts.filter { $0.id != account.id }) } }
                }
                Button("Ajouter un compte manuel") {
                    accountID = UUID(); name = ""; amount = ""; overdraft = false; kind = .checking; observed = Date(); editing = true
                }
            }
        }.navigationTitle("Mes soldes manuels")
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    TextField("Nom (ex. CIC personnel)", text: $name)
                    Picker("Type", selection: $kind) { ForEach(kinds, id: \.self) { Text(label($0)).tag($0) } }
                    TextField("Solde en euros (0 autorisé)", text: $amount).keyboardType(.decimalPad)
                    if kind == .checking { Toggle("Compte à découvert", isOn: $overdraft) }
                    DatePicker("Relevé le", selection: $observed, in: ...Date())
                    Text("Ne saisissez aucun numéro de compte ni identifiant bancaire. Ajoutez chaque compte une seule fois.").font(.caption)
                    if let error = store.error { Text(error).foregroundStyle(Color("Error")) }
                    Button("Enregistrer") {
                        guard let value = parsedAmount else { return }
                        let item = ManualFinancialAccount(id: accountID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), type: kind, cents: Int64(value) * (kind == .checking && overdraft ? -1 : 1), observedAt: observed)
                        save(accounts.filter { $0.id != accountID } + [item])
                        if store.error == nil { editing = false }
                    }.disabled(parsedAmount == nil || normalized(name).isEmpty)
                }.navigationTitle("Solde manuel")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { editing = false } } }
            }
        }
    }
    private var parsedAmount: Int? {
        if ["0", "0,00", "0.00"].contains(amount.trimmingCharacters(in: .whitespacesAndNewlines)) { return 0 }
        return ManualBudget.amountInCents(amount)
    }
    private func save(_ values: [ManualFinancialAccount]) {
        store.transact { snapshot in try ManualFinancialAccount.validate(values); snapshot.manualAccounts = values }
    }
}
