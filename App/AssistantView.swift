import SwiftUI
import DUOCore

/// Joe : on lui écrit comme à quelqu'un. Il répond, et propose une action que l'on confirme d'un geste.
struct AssistantView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var lines: [Line] = []
    @State private var thinking = false
    @FocusState private var focus: Bool

    struct Line: Identifiable { let id = UUID(); let text: String; let mine: Bool; var action: JoeAction? = nil; var ai = false; var done = false }

    private let examples = ["Qu'est-ce qu'on mange ce soir ?", "Rappelle-moi de sortir les poubelles demain", "Ajoute du lait aux courses", "J'ai dépensé 23,50 € chez Leclerc", "Rendez-vous dentiste jeudi à 14 h", "Que sais-tu faire ?"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if lines.isEmpty { intro }
                        ForEach($lines) { $line in bubble($line).id(line.id) }
                        if thinking {
                            HStack(spacing: 8) { ProgressView().tint(P.lav); Text("Joe réfléchit…").font(.system(size: 13)).foregroundStyle(P.mut) }.id("thinking")
                        }
                    }.padding(18)
                }
                .scrollIndicators(.hidden)
                .onChange(of: lines.count) { _, _ in withAnimation { proxy.scrollTo(lines.last?.id, anchor: .bottom) } }
            }
            HStack(spacing: 10) {
                TextField("Écris à Joe…", text: $question, axis: .vertical)
                    .lineLimit(1...4).focused($focus).submitLabel(.send).onSubmit(send)
                    .padding(.horizontal, 14).padding(.vertical, 12).glass(20).foregroundStyle(P.text)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundStyle(P.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(P.lav))
                }.buttonStyle(PressScale()).disabled(thinking || question.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Envoyer")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(hex: 0x100E16).opacity(0.95))
        }
        .background(DuoBackground())
        .preferredColorScheme(.dark)
        .navigationTitle("Joe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(RadialGradient(colors: [P.lav, P.lav.opacity(0.1)], center: .center, startRadius: 2, endRadius: 46)).frame(width: 84, height: 84)
                Image(systemName: "sparkles").font(.system(size: 30, weight: .semibold)).foregroundStyle(P.ink)
            }
            Text("Salut \(store.me.rawValue), moi c'est Joe.").font(P.serif(28)).foregroundStyle(P.text)
            Text(JoeBrain.aiAvailable ? "J'utilise l'intelligence d'Apple, directement sur ton iPhone : rien ne part sur Internet." : "Je fonctionne directement sur ton iPhone. Active Apple Intelligence dans les Réglages de l'iPhone pour que je comprenne encore mieux.")
                .font(.system(size: 13)).foregroundStyle(P.mut)
            Text("Essaie :").kicker().padding(.top, 6)
            ForEach(examples, id: \.self) { e in
                Button { question = e; send() } label: {
                    Text(e).font(.system(size: 14)).foregroundStyle(P.text).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).glass(16)
                }.buttonStyle(PressScale())
            }
        }.padding(.vertical, 8)
    }

    @ViewBuilder private func bubble(_ line: Binding<Line>) -> some View {
        let l = line.wrappedValue
        VStack(alignment: l.mine ? .trailing : .leading, spacing: 8) {
            Text(l.text).font(.system(size: 15)).foregroundStyle(l.mine ? P.ink : P.text).textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(l.mine ? AnyShapeStyle(P.lav) : AnyShapeStyle(P.card.opacity(0.9))))
            if let a = l.action {
                VStack(alignment: .leading, spacing: 8) {
                    Label(a.summary, systemImage: icon(a)).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                    if l.done {
                        Label("C'est fait", systemImage: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mint)
                    } else {
                        HStack(spacing: 8) {
                            PillButton(title: "Oui, fais-le", fill: P.mint, fg: Color(hex: 0x12251D)) { apply(a); if store.error == nil { line.wrappedValue.done = true } }
                            Button("Non merci") { line.wrappedValue.action = nil }.font(.system(size: 13, weight: .semibold)).foregroundStyle(P.mut).frame(minHeight: 44)
                        }
                    }
                }.padding(12).glass(18)
            }
            if l.ai { Text("Apple Intelligence · sur l'iPhone").font(.system(size: 10)).foregroundStyle(P.mut) }
        }
        .frame(maxWidth: .infinity, alignment: l.mine ? .trailing : .leading)
    }

    private func icon(_ a: JoeAction) -> String {
        switch a { case .task: return "checkmark.circle"; case .shopping: return "basket"; case .expense: return "eurosign.circle"; case .event: return "calendar" }
    }

    private func send() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        question = ""; lines.append(Line(text: q, mine: true))
        let local = JoeBrain.local(q, store: store)
        // Les demandes d'action claires sont comprises localement (instantané) ; le reste va à l'IA d'Apple si elle est là.
        if local.action != nil || !JoeBrain.aiAvailable { lines.append(Line(text: local.text, mine: false, action: local.action)); return }
        thinking = true
        Task {
            let ai = await JoeBrain.ai(q, store: store)
            thinking = false
            if let ai { lines.append(Line(text: ai.text, mine: false, action: ai.action, ai: true)) }
            else { lines.append(Line(text: local.text, mine: false, action: local.action)) }
        }
    }

    private func apply(_ a: JoeAction) {
        switch a {
        case .task(let t, let d, let p):
            let due = Calendar.current.date(byAdding: .day, value: d, to: Calendar.current.startOfDay(for: Date()))?.addingTimeInterval(19 * 3600)
            store.put(.task(HouseTask(title: t, assignee: store.assignee(for: p), due: due)))
        case .shopping(let n):
            store.put(.shopping(Shopping(ingredient: Ingredient(n, 1, .piece))))
        case .expense(let t, let c, let s):
            store.addBudget(BudgetEntry(date: Date(), kind: .expense, cents: c, title: t, person: store.me.rawValue, shared: s))
        case .event(let t, let start):
            store.put(.event(Event(title: t, start: start, end: start.addingTimeInterval(3600))))
        }
        if store.error == nil { store.toast = "Enregistré" }
    }
}
