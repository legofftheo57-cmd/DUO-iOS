import SwiftUI
import DUOCore

/// L'orbe d'épargne : un liquide qui monte à chaque euro mis de côté.
struct BudgetV2: View {
    @Environment(AppStore.self) private var store
    @AppStorage("duo.savingsGoal") private var goalEuros = 1000
    @State private var editingGoal = false
    @State private var showAll = false
    var body: some View {
        let cal = Calendar.current, now = Date()
        let entries = store.snapshot.manualBudget ?? []
        let year = entries.filter { cal.isDate($0.date, equalTo: now, toGranularity: .year) }
        let month = entries.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        let saved = Double(year.filter { $0.kind == .savings }.map(\.cents).reduce(0, +)) / 100
        let income = Double(month.filter { $0.kind == .income }.map(\.cents).reduce(0, +)) / 100
        let spent = Double(month.filter { $0.kind == .expense }.map(\.cents).reduce(0, +)) / 100
        let monthSaved = Double(month.filter { $0.kind == .savings }.map(\.cents).reduce(0, +)) / 100
        let common = Double(month.filter { $0.kind == .expense && $0.shared }.map(\.cents).reduce(0, +)) / 100
        let pct = goalEuros > 0 ? min(1, saved / Double(goalEuros)) : 0
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) { Text("Budget · \(now.formatted(.dateTime.month(.wide)))").kicker(); Text("Votre réserve").font(P.serif(32)).foregroundStyle(P.text) }
                    Spacer()
                    Text("Paie le 11").font(.system(size: 13)).foregroundStyle(P.mut).padding(.top, 8)
                }
                Button { editingGoal = true } label: {
                    LiquidOrb(level: pct, label: "\(Int((pct * 100).rounded())) %", sub: "de \(goalEuros) € d'objectif")
                        .frame(width: 220, height: 220).frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityLabel("Épargne : \(Int(saved)) euros sur \(goalEuros). Modifier l'objectif")

                HStack(spacing: 10) {
                    tile("Reste à vivre", income > 0 ? Brain.euros(income - spent - monthSaved) : "Ajoutez vos paies")
                    tile("Commun ce mois", Brain.euros(common))
                }
                VStack(spacing: 0) {
                    let sorted = entries.sorted { $0.date > $1.date }
                    let last = showAll ? Array(sorted) : Array(sorted.prefix(4))
                    if last.isEmpty { Text("Aucune opération ce mois-ci.").font(.system(size: 14)).foregroundStyle(P.mut).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10) }
                    ForEach(Array(last), id: \.id) { e in
                        HStack(spacing: 12) {
                            Avatar(person: DuoPerson(rawValue: e.person), size: 26)
                            VStack(alignment: .leading, spacing: 1) { Text(e.title).font(.system(size: 14)).foregroundStyle(P.text); Text(e.kind.rawValue + (e.shared ? " · commun" : "")).font(.system(size: 11)).foregroundStyle(P.mut) }
                            Spacer()
                            Text((e.kind == .income ? "+" : "") + Brain.euros(Double(e.cents) / 100)).font(.system(size: 14, weight: .semibold)).foregroundStyle(e.kind == .income ? P.mint : P.text)
                        }.frame(minHeight: 48)
                        .contentShape(Rectangle())
                        .contextMenu { Button("Supprimer", systemImage: "trash", role: .destructive) { removeEntry(e.id) } }
                    }
                    if sorted.count > 4 {
                        Button(showAll ? "Afficher moins" : "Voir les \(sorted.count) opérations") { withAnimation { showAll.toggle() } }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mint).frame(minHeight: 40)
                    }
                    if !sorted.isEmpty { Text("Appui long sur une opération pour la supprimer.").font(.system(size: 11)).foregroundStyle(P.mut).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6) }
                }.padding(.horizontal, 16).padding(.vertical, 6).glass(20)

                HStack(spacing: 8) {
                    PillButton(title: "Mettre 50 € de côté", fill: P.mint, fg: Color(hex: 0x12251D)) {
                        let e = BudgetEntry(date: Date(), kind: .savings, cents: 5000, title: "Épargne commune", person: store.me.rawValue)
                        store.transact { s in var b = s.manualBudget ?? []; b.append(e); try ManualBudget.validate(b); s.manualBudget = b }
                        if store.error == nil { store.toast = "50 € mis de côté" }
                    }
                    NavigationLink { BudgetView().navigationTitle("Budget détaillé") } label: {
                        Text("Détails").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text).padding(.horizontal, 16).frame(minHeight: 44).background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
            }.padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .alert("Objectif d'épargne", isPresented: $editingGoal) {
            Button("500 €") { goalEuros = 500 }; Button("1 000 €") { goalEuros = 1000 }; Button("2 000 €") { goalEuros = 2000 }; Button("5 000 €") { goalEuros = 5000 }
            Button("Annuler", role: .cancel) {}
        }
    }
    private func removeEntry(_ id: UUID) {
        store.transact { s in var b = s.manualBudget ?? []; b.removeAll { $0.id == id }; s.manualBudget = b }
        if store.error == nil { store.toast = "Opération supprimée" }
    }
    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12)).foregroundStyle(P.mut); Text(value).font(P.serif(21)).foregroundStyle(P.text).minimumScaleFactor(0.7).lineLimit(1) }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).glass(20)
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
