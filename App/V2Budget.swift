import SwiftUI
import DUOCore

/// Le budget du couple : l'orbe d'épargne, le reste à vivre, et toutes les opérations (partagées ou perso).
struct BudgetV2: View {
    @Environment(AppStore.self) private var store
    @AppStorage("duo.savingsGoal") private var goalEuros = 1000
    @State private var editingGoal = false
    @State private var showAll = false
    @State private var adding: BudgetKind?
    @State private var filter = 0 // 0 tout, 1 commun, 2 moi
    var body: some View {
        let cal = Calendar.current, now = Date()
        let rows = store.budgetRows
        let month = rows.filter { cal.isDate($0.1.date, equalTo: now, toGranularity: .month) }.map(\.1)
        let year = rows.filter { cal.isDate($0.1.date, equalTo: now, toGranularity: .year) }.map(\.1)
        let saved = Double(year.filter { $0.kind == .savings }.map(\.cents).reduce(0, +)) / 100
        let income = Double(month.filter { $0.kind == .income }.map(\.cents).reduce(0, +)) / 100
        let spent = Double(month.filter { $0.kind == .expense }.map(\.cents).reduce(0, +)) / 100
        let monthSaved = Double(month.filter { $0.kind == .savings }.map(\.cents).reduce(0, +)) / 100
        let common = Double(month.filter { $0.kind == .expense && $0.shared }.map(\.cents).reduce(0, +)) / 100
        let pct = goalEuros > 0 ? min(1, saved / Double(goalEuros)) : 0
        let shown = rows.filter { filter == 0 || (filter == 1 && $0.1.shared) || (filter == 2 && !$0.1.shared) }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) { Text("Budget · \(now.formatted(.dateTime.month(.wide)))").kicker(); Text("Votre réserve").font(P.serif(32)).foregroundStyle(P.text) }
                    Spacer()
                    Button { editingGoal = true } label: { Label("Objectif", systemImage: "target").font(.system(size: 12, weight: .semibold)) }.foregroundStyle(P.mint).padding(.top, 8)
                }
                Button { editingGoal = true } label: {
                    LiquidOrb(level: pct, label: "\(Int((pct * 100).rounded())) %", sub: "\(Brain.euros(saved)) sur \(goalEuros) €")
                        .frame(width: 220, height: 220).frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityLabel("Épargne : \(Int(saved)) euros sur \(goalEuros). Modifier l'objectif")

                HStack(spacing: 10) {
                    tile("Reste à vivre", income > 0 ? Brain.euros(income - spent - monthSaved) : "Ajoutez vos paies", P.mint)
                    tile("Dépenses communes", Brain.euros(common), P.peach)
                }
                HStack(spacing: 8) {
                    addButton("Dépense", "minus", P.peach, .expense)
                    addButton("Revenu", "plus", P.mint, .income)
                    addButton("Épargne", "arrow.down.to.line", P.lav, .savings)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Opérations").font(P.serif(19)).foregroundStyle(P.text)
                        Spacer()
                        Picker("Filtre", selection: $filter) { Text("Tout").tag(0); Text("Commun").tag(1); Text("Moi").tag(2) }.pickerStyle(.segmented).frame(width: 180)
                    }.padding(.vertical, 8)
                    let list = showAll ? Array(shown) : Array(shown.prefix(6))
                    if list.isEmpty { Text("Aucune opération. Ajoutez une dépense, un revenu ou de l'épargne.").font(.system(size: 14)).foregroundStyle(P.mut).padding(.vertical, 10) }
                    ForEach(list, id: \.0.id) { item in
                        let e = item.1
                        HStack(spacing: 12) {
                            Avatar(person: DuoPerson(rawValue: e.person), size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.title).font(.system(size: 14, weight: .medium)).foregroundStyle(P.text)
                                Text("\(e.kind.rawValue) · \(e.shared ? "commun" : "perso") · \(e.date.formatted(.dateTime.day().month(.abbreviated)))").font(.system(size: 11)).foregroundStyle(P.mut)
                            }
                            Spacer()
                            Text((e.kind == .income ? "+" : "−") + Brain.euros(Double(e.cents) / 100)).font(.system(size: 14, weight: .semibold)).foregroundStyle(e.kind == .income ? P.mint : (e.kind == .savings ? P.lav : P.text))
                        }
                        .frame(minHeight: 52).contentShape(Rectangle())
                        .contextMenu { Button("Supprimer", systemImage: "trash", role: .destructive) { withAnimation { store.removeBudget(item.0) }; if store.error == nil { store.toast = "Opération supprimée" } } }
                        Divider().opacity(0.2)
                    }
                    if shown.count > 6 {
                        Button(showAll ? "Afficher moins" : "Voir les \(shown.count) opérations") { withAnimation { showAll.toggle() } }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mint).frame(minHeight: 40)
                    }
                    if !list.isEmpty { Text("Appui long sur une opération pour la supprimer. « Commun » est visible par vous deux, « perso » seulement par toi.").font(.system(size: 11)).foregroundStyle(P.mut).padding(.vertical, 8) }
                }.padding(.horizontal, 16).padding(.vertical, 6).glass(20)
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.sync() }
        .onAppear { store.migrateLegacyBudget() }
        .sheet(item: $adding) { kind in BudgetAddSheet(kind: kind).presentationDetents([.medium, .large]).presentationBackground(Color(hex: 0x1A1724)) }
        .alert("Objectif d'épargne", isPresented: $editingGoal) {
            Button("500 €") { goalEuros = 500 }; Button("1 000 €") { goalEuros = 1000 }; Button("2 000 €") { goalEuros = 2000 }; Button("5 000 €") { goalEuros = 5000 }; Button("10 000 €") { goalEuros = 10000 }
            Button("Annuler", role: .cancel) {}
        }
    }
    private func addButton(_ t: String, _ symbol: String, _ c: Color, _ k: BudgetKind) -> some View {
        Button { adding = k } label: {
            Label(t, systemImage: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.ink)
                .frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c))
        }.buttonStyle(PressScale())
    }
    private func tile(_ title: String, _ value: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12)).foregroundStyle(P.mut); Text(value).font(P.serif(21)).foregroundStyle(P.text).minimumScaleFactor(0.7).lineLimit(1) }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(colors: [c.opacity(0.14), P.card.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.09)))
    }
}

struct BudgetAddSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var kind: BudgetKind
    @State private var title = ""
    @State private var amount = ""
    @State private var shared = true
    @State private var date = Date()
    @FocusState private var focus: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nouvelle opération").font(P.serif(24)).foregroundStyle(P.text)
            Picker("Type", selection: $kind) { ForEach(BudgetKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            TextField("Montant en €", text: $amount).keyboardType(.decimalPad).focused($focus).padding(14).glass(16).foregroundStyle(P.text).font(P.serif(24))
            TextField(kind == .expense ? "Ex. Courses Leclerc" : (kind == .income ? "Ex. Paie de novembre" : "Ex. Livret A"), text: $title).padding(14).glass(16).foregroundStyle(P.text)
            Toggle(isOn: $shared) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commun").foregroundStyle(P.text)
                    Text(shared ? "Visible par vous deux" : "Visible seulement par toi").font(.system(size: 12)).foregroundStyle(P.mut)
                }
            }.tint(P.mint)
            DatePicker("Date", selection: $date, displayedComponents: .date).foregroundStyle(P.text)
            PillButton(title: "Enregistrer", fill: P.mint, fg: Color(hex: 0x12251D)) { save() }
            Spacer()
        }
        .padding(22).preferredColorScheme(.dark)
        .onAppear { focus = true; shared = kind == .expense }
    }
    private func save() {
        guard let cents = ManualBudget.amountInCents(amount) else { store.error = "Montant invalide (ex. 23,50)."; return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = BudgetEntry(date: date, kind: kind, cents: cents, title: t.isEmpty ? kind.rawValue : t, person: store.me.rawValue, shared: shared)
        store.addBudget(entry)
        if store.error == nil { store.toast = "\(kind.rawValue) enregistrée"; dismiss() }
    }
}

struct LiquidOrb: View {
    let level: Double; let label: String; let sub: String
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().fill(RadialGradient(colors: [Color.white.opacity(0.12), Color(hex: 0x15131D)], center: UnitPoint(x: 0.3, y: 0.25), startRadius: 2, endRadius: 140))
                Wave(level: level, phase: t * 1.6, amplitude: 7).fill(P.mint.opacity(0.55))
                Wave(level: level, phase: t * 1.1 + 2, amplitude: 9).fill(LinearGradient(colors: [Color(hex: 0x9EE6C6), Color(hex: 0x3E8E6E)], startPoint: .top, endPoint: .bottom))
                Ellipse().fill(Color.white.opacity(0.2)).frame(width: 70, height: 34).blur(radius: 6).rotationEffect(.degrees(-25)).offset(x: -42, y: -66)
                VStack(spacing: 2) { Text(label).font(P.serif(48)); Text(sub).font(.system(size: 11, weight: .semibold)) }
                    .foregroundStyle(P.text).shadow(color: .black.opacity(0.6), radius: 8)
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.14)))
            .shadow(color: P.mint.opacity(0.18), radius: 40)
        }
    }
    struct Wave: Shape {
        var level: Double; var phase: Double; var amplitude: Double
        func path(in r: CGRect) -> Path {
            var p = Path()
            let y0 = r.maxY - r.height * CGFloat(max(0.04, min(1, level)))
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            for x in stride(from: r.minX, through: r.maxX, by: 4) {
                let rel = Double((x - r.minX) / r.width)
                p.addLine(to: CGPoint(x: x, y: y0 + CGFloat(sin(rel * 2 * .pi * 1.3 + phase) * amplitude)))
            }
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
            return p
        }
    }
}
