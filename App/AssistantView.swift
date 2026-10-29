import SwiftUI
import DUOCore

/// DUO's assistant never executes a write without an explicit user tap.
struct AssistantView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var exchanges: [ConversationLine] = []
    @State private var action: AssistantAction?
    @State private var waiting = false
    @State private var responseError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if exchanges.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Bonjour, moi c’est Joe.", systemImage: "sparkles").font(.title2.bold())
                                Text("Je peux suggérer un repas, résumer le planning et préparer une modification ou un ajout aux courses. Tu gardes toujours le dernier mot.")
                                    .foregroundStyle(.secondary)
                                ForEach(["Que cuisiner avec ce qu’on a ?", "Que prévoit notre planning ?", "Quelle marque acheter pour le riz ?", "Décale le sport à demain", "Ajoute 2 kg de riz aux courses"], id: \.self) { example in
                                    Button(example) { question = example }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12).background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }.padding(.vertical, 16)
                        }
                        ForEach(exchanges) { line in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(line.isUser ? "Vous" : line.isCloud ? "Joe · IA en ligne" : "Joe · local").font(.caption.bold()).foregroundStyle(.secondary)
                                Text(line.text).textSelection(.enabled)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(line.isUser ? Color("Ice").opacity(0.25) : Color("Surface"), in: RoundedRectangle(cornerRadius: 16))
                                .id(line.id)
                        }
                        if let action {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Proposition de Joe", systemImage: "checkmark.shield").font(.headline)
                                Text("Aucune modification ne sera effectuée sans ta confirmation.").font(.caption)
                                HStack {
                                    Button("Confirmer") { apply(action) }.buttonStyle(.borderedProminent)
                                    Button("Annuler") { self.action = nil }.buttonStyle(.bordered)
                                }
                            }.padding().background(Color("Surface"), in: RoundedRectangle(cornerRadius: 16))
                        }
                        if let responseError { Text(responseError).font(.caption).foregroundStyle(.red) }
                    }.padding(18)
                }
                .onChange(of: exchanges.count) { _, _ in if let id = exchanges.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
            }
            Divider()
            VStack(spacing: 9) {
                HStack {
                    TextField("Demande quelque chose à Joe…", text: $question, axis: .vertical)
                        .lineLimit(1...4).textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Question pour Joe")
                    Button { askLocal() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .disabled(waiting || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Réponse locale gratuite")
                }
                if store.backend?.session != nil {
                    Button {
                        Task { await askCloud() }
                    } label: {
                        HStack { Image(systemName: "network"); Text("Demander à l’IA en ligne (envoie uniquement ma question)") }
                            .font(.caption)
                    }.disabled(waiting || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Le mode local fonctionne sans réseau. Le mode en ligne exige une configuration serveur et une autorisation volontaire pour chaque question. Aucune action automatique.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(14).background(Color("Background"))
        }
        .background(Color("Background"))
        .navigationTitle("Joe")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
    }
    private func askLocal() {
        let value = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        responseError = nil; action = nil; question = ""
        exchanges.append(ConversationLine(text: value, isUser: true))
        let response = DuoAssistant.answer(value, records: store.records, recipes: Catalog.recipes,
                                           stock: store.foods, exclusions: store.exclusions)
        exchanges.append(ConversationLine(text: response.message))
        action = response.action
    }
    private func askCloud() async {
        let value = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !waiting else { return }
        responseError = nil; action = nil; question = ""; waiting = true
        exchanges.append(ConversationLine(text: value, isUser: true))
        defer { waiting = false }
        do {
            guard let backend = store.backend else { throw DuoError.unauthorized }
            let answer = try await backend.askAI(question: value)
            exchanges.append(ConversationLine(text: answer, isCloud: true))
        } catch {
            // Do not silently transmit a second time or fabricate a cloud reply.
            responseError = "Réponse en ligne indisponible : \(error.localizedDescription). Tu peux utiliser le mode local."
        }
    }
    private func apply(_ requested: AssistantAction) {
        responseError = nil
        switch requested {
        case .addShopping(let ingredient):
            // Revalidate when the user confirms, never when Joe merely proposes.
            store.put(.shopping(Shopping(ingredient: ingredient)))
        case .moveEvent(let id, let target), .moveTask(let id, let target):
            guard let row = store.records.first(where: { $0.id == id }) else {
                responseError = "L’élément n’existe plus."; action = nil; return
            }
            switch (requested, row.payload) {
            case (.moveEvent, .event(var event)):
                let duration = event.end.timeIntervalSince(event.start)
                event.start = target; event.end = target.addingTimeInterval(duration)
                store.put(.event(event), editing: row)
            case (.moveTask, .task(var task)):
                task.due = target; store.put(.task(task), editing: row)
            default:
                responseError = "Le type de l’élément a changé. Aucune action effectuée."
                action = nil; return
            }
        }
        action = nil
        if store.error == nil {
            exchanges.append(ConversationLine(text: "C’est fait. La modification est enregistrée sur cet iPhone et sera synchronisée lorsque le service sera configuré."))
            Task { await store.sync(showErrors: false) }
        } else { responseError = store.error }
    }
}
private struct ConversationLine: Identifiable {
    let id = UUID()
    let text: String
    var isUser = false
    var isCloud = false
}
