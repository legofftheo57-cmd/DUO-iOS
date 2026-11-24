import SwiftUI
import DUOCore

/// Nouvelle structure de l'app : 5 espaces, barre flottante, bouton « + ».
struct RootV2: View {
    @Environment(AppStore.self) private var store
    @Binding var settings: Bool
    @Binding var assistant: Bool
    @State private var tab = 0
    @State private var quick = false
    @State private var kitchenSegment = 0
    var body: some View {
        ZStack(alignment: .bottom) {
            DuoBackground()
            NavigationStack {
                ZStack {
                    DuoBackground()
                    switch tab {
                    case 0: HomeV2(tab: $tab, kitchenSegment: $kitchenSegment, settings: $settings, assistant: $assistant)
                    case 1: DayV2()
                    case 2: HouseV2()
                    case 3: KitchenV2(segment: $kitchenSegment)
                    default: BudgetV2()
                    }
                }
                .safeAreaPadding(.bottom, 84)
                .toolbar(.hidden, for: .navigationBar)
            }
            .transition(.opacity)

            HStack { Spacer()
                Button { quick = true } label: {
                    Image(systemName: "plus").font(.system(size: 24, weight: .medium)).foregroundStyle(P.ink)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xE3D8FF), Color(hex: 0xB39CFA)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .shadow(color: P.lav.opacity(0.45), radius: 16, y: 8)
                }.buttonStyle(.plain).accessibilityLabel("Ajouter rapidement")
            }.padding(.trailing, 20).padding(.bottom, 86)

            TabBarV2(tab: $tab).padding(.bottom, 4)

            if let t = store.toast {
                ToastView(text: t).padding(.bottom, 150)
                    .task(id: t) { try? await Task.sleep(for: .seconds(2.4)); withAnimation { if store.toast == t { store.toast = nil } } }
            }
        }
        .animation(.snappy, value: store.toast)
        .sheet(isPresented: $quick) {
            QuickAddV2(tab: $tab, kitchenSegment: $kitchenSegment).presentationDetents([.medium, .large]).presentationBackground(Color(hex: 0x1A1724))
        }
    }
}

struct HomeV2: View {
    @Environment(AppStore.self) private var store
    @Binding var tab: Int
    @Binding var kitchenSegment: Int
    @Binding var settings: Bool
    @Binding var assistant: Bool
    @State private var couple = false
    @AppStorage("duo.chef.day") private var chefDay = ""
    @AppStorage("duo.chef.text") private var chefText = ""
    var body: some View {
        let now = Date()
        let tonight = store.meal(on: now)
        let rest = store.leftovers.first
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide))).kicker()
                        Text("Bonjour \(store.me.rawValue)").font(P.serif(32)).foregroundStyle(P.text)
                    }
                    Spacer()
                    Button { assistant = true } label: { Image(systemName: "sparkles").frame(width: 44, height: 44) }.accessibilityLabel("Parler à Joe")
                    Button { settings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("Réglages")
                }
                .foregroundStyle(P.mut)

                OrbitV2(left: store.openTasks.filter { $0.1.due.map { Calendar.current.isDateInToday($0) || $0 < now } ?? false }.count,
                        progress: store.todayProgress) { index in
                    switch index { case 0: tab = 1; case 1: tab = 2; case 2: kitchenSegment = 0; tab = 3; case 3: tab = 4; default: couple = true }
                }
                .frame(height: 250)

                if !chefText.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "frying.pan").foregroundStyle(P.lav)
                        Text(chefText).font(.system(size: 14)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true)
                    }.padding(14).glass(20).accessibilityElement(children: .combine)
                }

                Button { kitchenSegment = 0; tab = 3 } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Ce soir · 19 h 30"); Spacer(); Text(cookLabel(now)) }
                            .font(.system(size: 11, weight: .bold)).tracking(1.2).textCase(.uppercase)
                        Text(rest.map { $0.1.name } ?? tonight.flatMap { store.recipe($0.1.recipeID)?.title } ?? "Rien de prévu · DUO a des idées")
                            .font(P.serif(23)).multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(P.ink).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LinearGradient(colors: [P.butter, Color(hex: 0xF3B79A)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .modifier(GentleTilt())
                }.buttonStyle(.plain)

                let props = store.proposals
                if !props.isEmpty {
                    Text("DUO a remarqué").kicker().padding(.top, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) { ForEach(props) { ProposalCardV2(p: $0) } }.scrollTargetLayout()
                    }.scrollTargetBehavior(.viewAligned).scrollClipDisabled()
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Les prochaines").font(P.serif(19)).foregroundStyle(P.text)
                        Spacer()
                        Button { withAnimation { store.imTired() } } label: {
                            Text("Je suis crevé").font(.system(size: 12, weight: .semibold)).foregroundStyle(P.text)
                                .padding(.horizontal, 12).frame(minHeight: 34).overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
                        }.buttonStyle(.plain)
                    }.padding(.bottom, 4)
                    let next = Array(store.openTasks.prefix(4))
                    if next.isEmpty { Text("Tout est fait. Profitez de la soirée.").font(.system(size: 14)).foregroundStyle(P.mut).padding(.vertical, 10) }
                    ForEach(next, id: \.0.id) { item in TaskLineV2(row: item.0, task: item.1) }
                    BalanceBar(theo: Brain.balance(store.snapshot.journal ?? [], now: now)).padding(.top, 8)
                }
                .padding(16).glass()
            }
            .padding(.horizontal, 18).padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $couple) { NavigationStack { CoupleIdeasView().navigationTitle("Nous deux") } }
        .task {
            let key = CoupleSchedule.dayKey(Date())
            guard chefDay != key, ChefAI.isAvailable else { return }
            if let text = await ChefAI.brief(context: store.chefContext) { chefText = text; chefDay = key }
        }
    }
    private func cookLabel(_ day: Date) -> String {
        if store.leftovers.first != nil { return "Rien à cuisiner" }
        return DuoSchedule.cook(on: day).map { "\($0.rawValue) cuisine" } ?? "À deux"
    }
}

/// Petite inclinaison 3D lente, coupée si « Réduire les animations ».
struct GentleTilt: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    func body(content: Self.Content) -> some View {
        if reduce { content } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                content
                    .rotation3DEffect(.degrees(sin(t / 1.6) * 5), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(3 + cos(t / 2.1) * 2), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            }
        }
    }
}

/// Le système solaire de l'accueil : anneau de progression au centre, 5 médaillons en orbite.
struct OrbitV2: View {
    let left: Int; let progress: Double; let open: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    private let planets: [(String, String, Color)] = [("Journée", "clock", P.lav), ("Maison", "house", P.sky), ("Cuisine", "fork.knife", P.butter), ("Budget", "drop", P.mint), ("Nous deux", "heart", P.rose)]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { ctx in
            let base = reduce ? 0.3 : ctx.date.timeIntervalSinceReferenceDate * 2 * .pi / 48
            GeometryReader { geo in
                let cx = geo.size.width / 2, cy = geo.size.height / 2
                let rx = min(150, geo.size.width / 2 - 34), ry: CGFloat = 52
                ZStack {
                    Ellipse().strokeBorder(P.lav.opacity(0.25), lineWidth: 1).frame(width: rx * 2, height: ry * 2).position(x: cx, y: cy)
                    ForEach(planets.indices, id: \.self) { i in
                        let a = base + Double(i) * 2 * .pi / Double(planets.count)
                        let depth = (sin(a) + 1) / 2
                        Button { open(i) } label: {
                            VStack(spacing: 5) {
                                Image(systemName: planets[i].1).font(.system(size: 18, weight: .regular)).foregroundStyle(planets[i].2)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.22)))
                                    .shadow(color: planets[i].2.opacity(0.35), radius: 12)
                                Text(planets[i].0).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.text)
                            }
                            .frame(minWidth: 64, minHeight: 72).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(0.78 + 0.3 * depth)
                        .opacity(0.6 + 0.4 * depth)
                        .position(x: cx + rx * cos(a), y: cy + ry * sin(a) - 6)
                        .zIndex(sin(a) > 0 ? 2 : 0)
                        .accessibilityLabel("Ouvrir \(planets[i].0)")
                    }
                    ZStack {
                        Circle().fill(RadialGradient(colors: [Color(hex: 0x2E2840), Color(hex: 0x14121C)], center: UnitPoint(x: 0.35, y: 0.25), startRadius: 2, endRadius: 70))
                        Circle().trim(from: 0, to: max(0.02, progress)).stroke(P.lav, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90)).padding(1.5)
                        Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 3)
                        VStack(spacing: 2) {
                            Text("\(left)").font(P.serif(36)).foregroundStyle(P.text)
                            Text("À FAIRE").font(.system(size: 9.5, weight: .bold)).tracking(1.6).foregroundStyle(P.mut)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .shadow(color: P.lav.opacity(0.25), radius: 30)
                    .position(x: cx, y: cy)
                    .zIndex(1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(left) choses à faire aujourd'hui")
                }
            }
        }
    }
}

struct ProposalCardV2: View {
    @Environment(AppStore.self) private var store
    let p: Proposal
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle().fill(P.tints[p.tint % P.tints.count]).frame(width: 8, height: 8)
            Text(p.title).font(P.serif(17)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true)
            Text(p.detail).font(.system(size: 13)).foregroundStyle(P.mut).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                PillButton(title: p.accept, fill: P.tints[p.tint % P.tints.count]) { withAnimation { store.accept(p) } }
                Button("Pas maintenant") { withAnimation { store.dismiss(p) } }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mut).frame(minHeight: 44)
            }
        }
        .padding(16).frame(width: 270, height: 200, alignment: .topLeading).glass()
    }
}

struct BalanceBar: View {
    let theo: Int
    var body: some View {
        HStack(spacing: 8) {
            Text("Équilibre").font(.system(size: 12)).foregroundStyle(P.mut)
            GeometryReader { g in
                ZStack(alignment: .leading) { Capsule().fill(P.peach); Capsule().fill(P.lav).frame(width: g.size.width * CGFloat(theo) / 100) }
            }.frame(height: 6)
            Text("T \(theo) %").font(.system(size: 12)).foregroundStyle(P.lav)
            Text("L \(100 - theo) %").font(.system(size: 12)).foregroundStyle(P.peach)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tâches de la semaine : Théo \(theo) pour cent, Lilou \(100 - theo) pour cent")
    }
}

/// Le bouton « + » : ajouter en deux gestes.
struct QuickAddV2: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var tab: Int
    @Binding var kitchenSegment: Int
    @State private var mode = 0
    @State private var text = ""
    @State private var who: DuoPerson? = nil
    @State private var repeatDays = 0
    @State private var amount = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajouter vite").font(P.serif(24)).foregroundStyle(P.text)
            Picker("Type", selection: $mode) { Text("Tâche").tag(0); Text("Course").tag(1); Text("Dépense").tag(2) }.pickerStyle(.segmented)
            TextField(mode == 0 ? "Ex. Nettoyer le four" : (mode == 1 ? "Ex. Lait" : "Ex. Courses Intermarché"), text: $text)
                .padding(14).glass(16).foregroundStyle(P.text).submitLabel(.done)
            if mode == 0 {
                Picker("Pour", selection: $who) { Text("À deux").tag(DuoPerson?.none); ForEach(DuoPerson.allCases, id: \.self) { Text($0.rawValue).tag(DuoPerson?.some($0)) } }.pickerStyle(.segmented)
                Picker("Revient", selection: $repeatDays) { Text("Une fois").tag(0); Text("Chaque jour").tag(1); Text("Chaque semaine").tag(7); Text("Toutes les 2 sem.").tag(14) }.pickerStyle(.segmented)
            }
            if mode == 2 { TextField("Montant en €", text: $amount).keyboardType(.decimalPad).padding(14).glass(16).foregroundStyle(P.text) }
            PillButton(title: "Ajouter") { add() }.disabled(normalized(text).isEmpty)
            Spacer()
        }
        .padding(22).preferredColorScheme(.dark)
    }
    private func add() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case 0:
            store.put(.task(HouseTask(title: title, assignee: store.assignee(for: who), due: Calendar.current.startOfDay(for: Date()).addingTimeInterval(19 * 3600), repeatDays: repeatDays)))
            if store.error == nil { store.toast = "Tâche ajoutée"; tab = 2 }
        case 1:
            store.put(.shopping(Shopping(ingredient: Ingredient(title, 1, .piece))))
            if store.error == nil { store.toast = "\(title) ajouté aux courses"; kitchenSegment = 1; tab = 3 }
        default:
            guard let cents = ManualBudget.amountInCents(amount) else { store.error = "Montant invalide."; return }
            let entry = BudgetEntry(date: Date(), kind: .expense, cents: cents, title: title, person: store.me.rawValue, shared: true)
            store.transact { s in var b = s.manualBudget ?? []; b.append(entry); try ManualBudget.validate(b); s.manualBudget = b }
            if store.error == nil { store.toast = "Dépense notée"; tab = 4 }
        }
        if store.error == nil { dismiss() }
    }
}
