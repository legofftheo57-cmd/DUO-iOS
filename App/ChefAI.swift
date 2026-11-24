import Foundation
import DUOCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Le chef et organisateur discret de DUO.
/// Il utilise l'IA d'Apple intégrée à l'iPhone (Apple Intelligence, iOS 26+) :
/// gratuite, sans réseau, aucune donnée ne quitte le téléphone.
/// On ne lui parle pas : DUO lui donne le contexte, il rédige un conseil court.
/// Sans Apple Intelligence, DUO garde ses règles locales (Brain) : rien ne casse.
enum ChefAI {
    static let instructions = """
    Tu es le chef cuisinier et l'organisateur discret d'un jeune couple français, Théo et Lilou, qui vivent ensemble \
    avec un petit budget. Théo travaille en usine en 2×8 (une semaine le matin dès 5 h 28, une semaine le soir jusqu'à 20 h 32). \
    Lilou travaille de 8 h à 17 h (16 h le vendredi). À partir du contexte fourni, écris UN conseil pour aujourd'hui : \
    2 phrases maximum, en français, tutoiement, concret, chaleureux sans flatterie. Priorités : ne rien gaspiller, \
    dépenser le moins possible, ménager la fatigue, répartir équitablement. N'invente aucun produit absent du contexte.
    """

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func brief(context: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: context)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : String(text.prefix(280))
            } catch { return nil }
        }
        #endif
        return nil
    }
}

extension AppStore {
    /// Contexte factuel envoyé au modèle local (jamais au réseau).
    var chefContext: String {
        let now = Date(), cal = Calendar.current
        var lines: [String] = []
        lines.append("Nous sommes \(Brain.weekdayName(now)) \(now.formatted(.dateTime.day().month(.wide))). Je suis \(me.rawValue).")
        for p in DuoPerson.allCases {
            if let w = DuoSchedule.work(p, on: now) {
                lines.append("\(p.rawValue) travaille de \(w.start / 60) h \(String(format: "%02d", w.start % 60)) à \(w.end / 60) h \(String(format: "%02d", w.end % 60)) (énergie \(DuoSchedule.energy(p, on: now))/3).")
            } else { lines.append("\(p.rawValue) est en repos aujourd'hui.") }
        }
        if let m = meal(on: now), let r = recipe(m.1.recipeID) { lines.append("Repas prévu ce soir : \(r.title)\(m.1.cooked ? " (déjà mangé)" : "").") }
        else { lines.append("Aucun repas prévu ce soir.") }
        let soon = foods.filter { f in f.expiry.map { $0 < cal.startOfDay(for: now).addingTimeInterval(3 * 86400) } ?? false }.map(\.name)
        if !soon.isEmpty { lines.append("À finir vite : \(soon.prefix(5).joined(separator: ", ")).") }
        let fridge = foods.prefix(12).map(\.name)
        if !fridge.isEmpty { lines.append("Au frigo et placards : \(fridge.joined(separator: ", ")).") }
        let todo = openTasks.prefix(5).map { "\($0.1.title) (\(person(forAssignee: $0.1.assignee)?.rawValue ?? "à deux"))" }
        if !todo.isEmpty { lines.append("Tâches ouvertes : \(todo.joined(separator: ", ")).") }
        lines.append("Équilibre des tâches sur 7 jours : Théo \(Brain.balance(snapshot.journal ?? [], now: now)) %.")
        return lines.joined(separator: "\n")
    }
}
