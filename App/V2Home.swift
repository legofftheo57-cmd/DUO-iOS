import SwiftUI
import SceneKit
import UIKit
import DUOCore

/// Nouvelle structure de l'app : 5 espaces, barre flottante, bouton « + ».
struct RootV2: View {
    @Environment(AppStore.self) private var store
    @Binding var settings: Bool
    @Binding var assistant: Bool
    @State private var tab: Int = {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-duo-tab"), a.count > i + 1, let n = Int(a[i + 1]) { return n }
        return 0
    }()
    @State private var quick = false
    @State private var kitchenSegment: Int = {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-duo-kitchen"), a.count > i + 1, let n = Int(a[i + 1]) { return n }
        return 0
    }()
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

            // 1.1 : le « + » vit à côté de la barre d'onglets (il ne couvre plus le contenu).
            HStack(spacing: 10) {
                TabBarV2(tab: $tab)
                Button { quick = true } label: {
                    Image(systemName: "plus").font(.system(size: 24, weight: .medium)).foregroundStyle(P.ink)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xE3D8FF), Color(hex: 0xB39CFA)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .shadow(color: P.lav.opacity(0.45), radius: 16, y: 8)
                }.buttonStyle(.plain).accessibilityLabel("Ajouter rapidement")
            }.padding(.horizontal, 12).padding(.bottom, 4)

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
    @State private var account = false
    @AppStorage("duo.room") private var room = 1
    @AppStorage("duo.chef.day") private var chefDay = ""
    @AppStorage("duo.chef.text") private var chefText = ""
    @State private var appeared = false

    private func greeting(_ d: Date) -> String {
        let h = Calendar.current.component(.hour, from: d)
        return h < 5 ? "Bonne nuit" : h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir"
    }
    private var roomCounts: [Int] { (0..<4).map { i in store.openTasks.filter { Brain.room(for: $0.1.title) == i }.count } }

    var body: some View {
        let now = Date()
        let tonight = store.meal(on: now)
        let rest = store.leftovers.first
        let todayTasks = store.openTasks.filter { $0.1.due.map { Calendar.current.isDateInToday($0) || $0 < now } ?? false }
        let idea = CoupleIdeasView.ideaOfDay(now)
        let tonightText = rest.map { "restes de \($0.1.name)" } ?? tonight.flatMap { store.recipe($0.1.recipeID)?.title } ?? "soirée libre"
        ScrollView {
            VStack(spacing: 16) {
                // En-tête discret
                HStack(spacing: 0) {
                    Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide))).kicker()
                    Spacer()
                    SyncDot(state: store.linkState, busy: store.syncInFlight) { account = true }
                    Button { assistant = true } label: { Image(systemName: "sparkles").frame(width: 44, height: 44) }.accessibilityLabel("Parler à Joe")
                    Button { settings = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }.accessibilityLabel("Réglages")
                }
                .foregroundStyle(P.mut)

                if store.linkState == .signedOut || store.linkState == .noHome {
                    Button { account = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.radiowaves.left.and.right").font(.system(size: 18)).foregroundStyle(P.ink)
                                .frame(width: 38, height: 38).background(Circle().fill(P.peach))
                            Text(store.linkState == .signedOut ? "Reliez vos deux téléphones" : "Dernière étape : le foyer").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(P.mut)
                        }.padding(12).glass(18)
                    }.buttonStyle(.plain)
                }

                // L'objet 3D et son aura
                ZStack {
                    Circle().fill(RadialGradient(colors: [AuraPalette.now(now)[0].opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: 150))
                        .frame(width: 300, height: 300).blur(radius: 20)
                    AuraHero().frame(height: 240)
                }
                .frame(height: 240)
                .scaleEffect(appeared ? 1 : 0.9).opacity(appeared ? 1 : 0)
                .accessibilityHidden(true)

                // L'heure, en grand
                VStack(spacing: 4) {
                    TimelineView(.everyMinute) { ctx in
                        Text(AuraPalette.clock(ctx.date)).font(.system(size: 84, weight: .thin)).monospacedDigit().foregroundStyle(P.text)
                            .contentTransition(.numericText())
                    }
                    Text("\(greeting(now)) \(store.me.rawValue)").font(P.serif(22)).foregroundStyle(P.text.opacity(0.9))
                    HStack(spacing: 6) {
                        Button { withAnimation(.snappy) { tab = 2 } } label: { Text(todayTasks.isEmpty ? "rien à faire" : "\(todayTasks.count) à faire") }
                        Text("·")
                        Button { kitchenSegment = 0; withAnimation(.snappy) { tab = 3 } } label: { Text("ce soir : \(tonightText)").lineLimit(1) }
                        Text("·")
                        Button { withAnimation(.snappy) { tab = 4 } } label: { Text(Brain.euros(store.monthLeft)) }
                    }
                    .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(P.mut).padding(.top, 2)
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 10)

                // Un moment à deux : une idée concrète, tout de suite
                Button { couple = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: idea.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(P.ink)
                            .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(LinearGradient(colors: [P.peach, P.lav], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Un moment à deux · \(idea.minutes) min").kicker()
                            Text(idea.title).font(P.serif(19)).foregroundStyle(P.text)
                            Text(idea.detail).font(.system(size: 13)).foregroundStyle(P.mut).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).glass(24)
                }.buttonStyle(PressScale())

                // Les prochaines tâches
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Les prochaines tâches").kicker()
                        Spacer()
                        Button { withAnimation { store.imTired() } } label: {
                            Text("Je suis crevé").font(.system(size: 12, weight: .semibold)).foregroundStyle(P.text)
                                .padding(.horizontal, 12).frame(minHeight: 34).overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.2)))
                        }.buttonStyle(.plain)
                    }
                    let next = Array(store.openTasks.prefix(3))
                    if next.isEmpty { Text("Tout est fait. Profitez de la soirée.").font(.system(size: 14)).foregroundStyle(P.mut).padding(.vertical, 10) }
                    ForEach(next, id: \.0.id) { item in TaskLineV2(row: item.0, task: item.1) }
                }
                .padding(16).glass(24)

                // DUO a remarqué : une seule proposition, la plus utile
                if let p = store.proposals.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DUO a remarqué").kicker()
                        Text(p.title).font(P.serif(18)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true)
                        Text(p.detail).font(.system(size: 13)).foregroundStyle(P.mut).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            PillButton(title: p.accept, fill: P.tints[p.tint % P.tints.count]) { withAnimation { store.accept(p) } }
                            Button("Pas maintenant") { withAnimation { store.dismiss(p) } }
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mut).frame(minHeight: 44)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).glass(24)
                }

                if let next = store.nextAppointment(after: now) {
                    Button { withAnimation(.snappy) { tab = 1 } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar").foregroundStyle(P.sky)
                            Text("Prochain rendez-vous : \(next.title)").lineLimit(1)
                            Spacer()
                            Text(next.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "fr_FR")))).foregroundStyle(P.mut)
                        }
                        .font(.system(size: 13)).foregroundStyle(P.text).padding(.horizontal, 16).frame(minHeight: 48).glass(18)
                    }.buttonStyle(.plain)
                }

                if !chefText.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "frying.pan").foregroundStyle(P.butter)
                        Text(chefText).font(.system(size: 14)).foregroundStyle(P.text).fixedSize(horizontal: false, vertical: true)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(20).accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AuraBackground().ignoresSafeArea())
        .refreshable { await store.sync() }
        .sheet(isPresented: $couple) { NavigationStack { CoupleIdeasView().navigationTitle("Nous deux") } }
        .sheet(isPresented: $account) { NavigationStack { AccountView() } }
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { appeared = true } }
        .task {
            let key = CoupleSchedule.dayKey(Date())
            guard chefDay != key, ChefAI.isAvailable else { return }
            if let text = await ChefAI.brief(context: store.chefContext) { chefText = text; chefDay = key }
        }
    }
}

/// 1.2 : couleurs de l'aura selon le moment de la journée (aube, journée, soirée, nuit).
enum AuraPalette {
    static func now(_ d: Date) -> [Color] {
        let h = Calendar.current.component(.hour, from: d)
        switch h {
        case 5..<11: return [Color(hex: 0xFFB89A), Color(hex: 0xFFE3A8), Color(hex: 0xC8B6FF)]
        case 11..<17: return [Color(hex: 0x9CC8FF), Color(hex: 0xB8F0D8), Color(hex: 0xC8B6FF)]
        case 17..<22: return [Color(hex: 0xB79CFF), Color(hex: 0xFF9E80), Color(hex: 0xF7A6C8)]
        default: return [Color(hex: 0x6E5BFF), Color(hex: 0x3FA0C8), Color(hex: 0xB79CFF)]
        }
    }
    static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

/// 1.2 : le fond de l'accueil. Trois grandes lueurs floues qui dérivent lentement, aux couleurs de l'heure.
struct AuraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var drift = false
    var body: some View {
        let c = AuraPalette.now(Date())
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                Color(hex: 0x06050A)
                Circle().fill(c[0]).frame(width: w * 1.1, height: w * 1.1).blur(radius: 90).opacity(0.55)
                    .offset(x: drift ? -w * 0.25 : w * 0.05, y: drift ? -w * 0.55 : -w * 0.35)
                Circle().fill(c[1]).frame(width: w * 0.9, height: w * 0.9).blur(radius: 90).opacity(0.45)
                    .offset(x: drift ? w * 0.35 : w * 0.1, y: drift ? -w * 0.1 : -w * 0.4)
                Circle().fill(c[2]).frame(width: w * 0.8, height: w * 0.8).blur(radius: 100).opacity(0.35)
                    .offset(x: drift ? -w * 0.1 : -w * 0.3, y: drift ? w * 0.5 : w * 0.2)
                LinearGradient(colors: [.clear, Color(hex: 0x06050A).opacity(0.75), Color(hex: 0x06050A)], startPoint: .center, endPoint: .bottom)
            }
            .frame(width: g.size.width, height: g.size.height)
            .drawingGroup()
        }
        .onAppear { guard !reduce else { return }; withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true } }
    }
}

/// 1.2 : l'objet 3D de l'accueil. Un anneau de métal poli qui tourne lentement
/// et reflète des lumières de couleur (lavande, pêche, menthe, ciel).
struct AuraHero: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isUserInteractionEnabled = false
        let scene = SCNScene()
        let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera?.fieldOfView = 30; cam.position = SCNVector3(0, 0, 6.4)
        scene.rootNode.addChildNode(cam)

        let torus = SCNTorus(ringRadius: 1.05, pipeRadius: 0.34)
        torus.ringSegmentCount = 120; torus.pipeSegmentCount = 48
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(white: 0.1, alpha: 1)
        m.metalness.contents = 1.0
        m.roughness.contents = 0.14
        torus.materials = [m]
        let ring = SCNNode(geometry: torus)
        ring.eulerAngles = SCNVector3(Float.pi / 2.7, 0, 0.35)
        let spin = SCNNode(); spin.addChildNode(ring); scene.rootNode.addChildNode(spin)

        scene.lightingEnvironment.contents = Self.environment()
        scene.lightingEnvironment.intensity = 2.0

        let pivot = SCNNode(); scene.rootNode.addChildNode(pivot)
        let colors: [UIColor] = [UIColor(P.lav), UIColor(P.peach), UIColor(P.mint), UIColor(P.sky)]
        for (i, c) in colors.enumerated() {
            let l = SCNNode(); let light = SCNLight(); light.type = .omni; light.color = c; light.intensity = 1100
            l.light = light
            let a = Float(i) * Float.pi / 2
            l.position = SCNVector3(cos(a) * 3, sin(a) * 1.8, 2.4)
            pivot.addChildNode(l)
        }
        if !UIAccessibility.isReduceMotionEnabled {
            spin.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 22)))
            pivot.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 13)))
            ring.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.08, z: 0, duration: 3), .moveBy(x: 0, y: -0.08, z: 0, duration: 3)])))
        }
        view.scene = scene
        view.pointOfView = cam
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}

    /// Ciel de reflets en bandes de couleur : c'est lui qui donne les reflets irisés au métal.
    static func environment() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cols = [UIColor(P.lav), UIColor(P.peach), UIColor(red: 0.063, green: 0.063, blue: 0.094, alpha: 1), UIColor(P.mint), UIColor(P.sky), UIColor(red: 0.063, green: 0.063, blue: 0.094, alpha: 1), UIColor(P.rose), UIColor(P.lav)].map { $0.cgColor }
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols as CFArray, locations: nil) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            }
            UIColor.black.withAlphaComponent(0.35).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))
        }
    }
}

/// Petit indicateur de connexion : vert = relié, orange = à relier, gris = un seul téléphone.
struct SyncDot: View {
    let state: LinkState; let busy: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 30, height: 30)
                if busy { ProgressView().scaleEffect(0.6).tint(color) }
                else { Image(systemName: state == .linked ? "link" : "link.badge.plus").font(.system(size: 12, weight: .bold)).foregroundStyle(color) }
            }.frame(width: 44, height: 44)
        }.buttonStyle(.plain)
        .accessibilityLabel(state == .linked ? "Téléphones reliés" : "Relier les téléphones")
    }
    private var color: Color { state == .linked ? P.mint : (state == .noServer ? P.mut : P.peach) }
}

struct StatTile: View {
    let title: String; let value: String; let detail: String; let symbol: String; let tint: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.ink)
                    .frame(width: 30, height: 30).background(Circle().fill(tint))
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.mut).textCase(.uppercase).tracking(0.8)
                Text(value).font(P.serif(22)).foregroundStyle(P.text).lineLimit(1).minimumScaleFactor(0.6)
                Text(detail).font(.system(size: 11)).foregroundStyle(P.mut).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [tint.opacity(0.16), P.card.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.09)))
        }.buttonStyle(PressScale())
        .accessibilityElement(children: .combine)
    }
}

/// Retour visuel au toucher : léger enfoncement.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).animation(.snappy(duration: 0.2), value: configuration.isPressed)
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
            store.addBudget(entry)
            if store.error == nil { store.toast = "Dépense notée"; tab = 4 }
        }
        if store.error == nil { dismiss() }
    }
}
