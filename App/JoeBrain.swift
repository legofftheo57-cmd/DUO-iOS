import Foundation
import DUOCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Ce que Joe propose de faire : rien n'est enregistré sans un geste de confirmation.
enum JoeAction: Equatable {
    case task(title: String, inDays: Int, person: DuoPerson?)
    case shopping(name: String)
    case expense(title: String, cents: Int, shared: Bool)
    case event(title: String, start: Date)

    var summary: String {
        switch self {
        case .task(let t, let d, let p): return "Tâche « \(t) »" + (d == 0 ? " pour aujourd'hui" : d == 1 ? " pour demain" : " dans \(d) jours") + (p.map { " · \($0.rawValue)" } ?? " · à deux")
        case .shopping(let n): return "Ajouter « \(n) » aux courses"
        case .expense(let t, let c, let s): return "Dépense \(Brain.euros(Double(c) / 100)) · \(t)" + (s ? " · commune" : " · perso")
        case .event(let t, let d): return "Rendez-vous « \(t) » · " + d.formatted(.dateTime.weekday(.wide).day().month().hour().minute())
        }
    }
}
struct JoeReply { var text: String; var action: JoeAction?; var usedAI = false }

enum JoeBrain {
    static let capabilities = """
    Je connais toute l'app DUO et je peux :
    • ajouter une tâche dans la maison (« rappelle-moi de sortir les poubelles demain »)
    • ajouter un article aux courses (« ajoute du lait aux courses »)
    • noter une dépense (« j'ai dépensé 23,50 € chez Leclerc »)
    • créer un rendez-vous (« rendez-vous dentiste jeudi à 14 h »)
    • te dire ce qu'il reste à faire, ce qu'on mange ce soir, ce qui périme bientôt
    • résumer le budget du mois et le planning de la semaine
    Tu confirmes toujours avant que j'enregistre quoi que ce soit.
    """

    static func instructions(_ store: AppStore) -> String {
        """
        Tu es Joe, l'assistant de l'application DUO de Théo et Lilou, un jeune couple français qui vit ensemble avec un petit budget. \
        Tu parles à \(store.me.rawValue). Réponds en français, en tutoyant, en 1 à 4 phrases, concret et chaleureux, sans flatterie. \
        L'application contient : Accueil (résumé du jour et maison 3D), Calendrier (mois, rendez-vous, horaires de travail, calendriers de l'iPhone), \
        Maison (4 pièces : Cuisine, Salon, Chambre, Salle de bain, avec leurs tâches), Cuisine (repas de la semaine, courses, frigo, chef), \
        Budget (dépenses, revenus, épargne, communes ou perso, objectif d'épargne). Les deux téléphones partagent les données. \
        Tu peux PROPOSER une seule action quand on te le demande : tache, course, depense ou rendezvous. Sinon action = aucune. \
        N'invente jamais un chiffre, un produit ou un rendez-vous absent du contexte. Si tu ne sais pas, dis-le.
        """
    }

    static func context(_ store: AppStore) -> String {
        var lines = [store.chefContext]
        lines.append("Reste à vivre ce mois : \(Brain.euros(store.monthLeft)).")
        let shop = store.shoppingRows.filter { !$0.1.checked }.prefix(12).map(\.1.ingredient.name)
        if !shop.isEmpty { lines.append("Liste de courses : \(shop.joined(separator: ", ")).") }
        let soon = store.records.compactMap { r -> String? in
            if case .event(let e) = r.payload, e.start > Date(), e.start < Date().addingTimeInterval(7 * 86400) { return "\(e.title) le \(e.start.formatted(.dateTime.weekday(.wide).hour().minute()))" }
            return nil
        }
        if !soon.isEmpty { lines.append("Rendez-vous de la semaine : \(soon.prefix(6).joined(separator: " ; ")).") }
        return lines.joined(separator: "\n")
    }

    // MARK: Compréhension locale (toujours disponible, sans réseau)
    static func local(_ question: String, store: AppStore) -> JoeReply {
        let q = normalized(question).replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "'", with: " ").replacingOccurrences(of: "’", with: " ")
        let raw = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return JoeReply(text: "Écris-moi ce que tu veux faire.") }
        if ["aide", "que sais tu", "tu sais faire", "tu peux faire", "comment ca marche", "quoi faire"].contains(where: { q.contains($0) }) {
            return JoeReply(text: capabilities)
        }
        // Courses
        if let r = q.range(of: "aux courses") ?? q.range(of: "a la liste") {
            let head = String(q[..<r.lowerBound])
            let name = cleanItem(head.replacingOccurrences(of: "ajoute", with: "").replacingOccurrences(of: "rajoute", with: "").replacingOccurrences(of: "mets", with: ""))
            if !name.isEmpty { return JoeReply(text: "Je l'ajoute à la liste de courses ?", action: .shopping(name: name.capitalizedFirst)) }
        }
        if q.hasPrefix("acheter ") || q.hasPrefix("achete ") {
            let name = cleanItem(String(q.drop(while: { $0 != " " })))
            if !name.isEmpty { return JoeReply(text: "Je l'ajoute aux courses ?", action: .shopping(name: name.capitalizedFirst)) }
        }
        // Dépense
        if (q.contains("depense") || q.contains("paye") || q.contains("achete pour")), let cents = amount(in: raw) {
            var title = raw
            if let r = raw.range(of: "chez ", options: .caseInsensitive) { title = String(raw[r.upperBound...]) }
            else if let r = raw.range(of: " en ", options: .caseInsensitive) { title = String(raw[r.upperBound...]) }
            else if let r = raw.range(of: " pour ", options: .caseInsensitive) { title = String(raw[r.upperBound...]) }
            else { title = "Dépense" }
            title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let shared = !(q.contains("perso") || q.contains("pour moi"))
            return JoeReply(text: "Je note cette dépense\(shared ? " commune" : " perso") ?", action: .expense(title: title.isEmpty ? "Dépense" : title.capitalizedFirst, cents: cents, shared: shared))
        }
        // Rendez-vous
        if q.contains("rendez vous") || q.contains("rdv") {
            let d = dayOffset(q) ?? 0
            let h = hour(in: q) ?? 9
            var title = raw
            for w in ["rendez-vous", "Rendez-vous", "rendez vous", "rdv", "RDV", "ajoute", "crée", "cree"] { title = title.replacingOccurrences(of: w, with: "") }
            title = stripDate(title)
            let start = Calendar.current.date(bySettingHour: h, minute: minutes(in: q), second: 0, of: Calendar.current.date(byAdding: .day, value: d, to: Date()) ?? Date()) ?? Date()
            return JoeReply(text: "Je crée ce rendez-vous ?", action: .event(title: title.isEmpty ? "Rendez-vous" : title.capitalizedFirst, start: start))
        }
        // Tâche
        for p in ["rappelle moi de ", "rappelle moi d ", "il faut ", "faut ", "tache ", "ajoute la tache ", "penser a "] where q.contains(p) {
            if let r = q.range(of: p) {
                let rest = stripDate(String(q[r.upperBound...]))
                let person: DuoPerson? = q.contains("lilou") ? .lilou : (q.contains("theo") ? .theo : nil)
                let title = rest.replacingOccurrences(of: "pour lilou", with: "").replacingOccurrences(of: "pour theo", with: "").trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { return JoeReply(text: "J'ajoute cette tâche ?", action: .task(title: title.capitalizedFirst, inDays: dayOffset(q) ?? 0, person: person)) }
            }
        }
        // Questions
        if q.contains("reste a faire") || q.contains("taches") || q.contains("quoi faire aujourd") {
            let open = store.openTasks.prefix(6).map { "• \($0.1.title)" + (store.person(forAssignee: $0.1.assignee).map { " (\($0.rawValue))" } ?? "") }
            return JoeReply(text: open.isEmpty ? "Tout est fait. Profitez-en." : "Il reste :\n" + open.joined(separator: "\n"))
        }
        if q.contains("budget") || q.contains("reste a vivre") || q.contains("combien il reste") {
            return JoeReply(text: "Ce mois-ci, il vous reste \(Brain.euros(store.monthLeft)) une fois les dépenses et l'épargne retirées.")
        }
        if q.contains("perime") || q.contains("frigo") {
            let soon = store.foods.filter { $0.expiry.map { $0 < Date().addingTimeInterval(3 * 86400) } ?? false }.map(\.name)
            return JoeReply(text: soon.isEmpty ? "Rien ne périme dans les 3 jours." : "À finir vite : \(soon.joined(separator: ", ")).")
        }
        if q.contains("mange") || q.contains("cuisiner") || q.contains("repas") || q.contains("diner") {
            if let m = store.meal(on: Date()), let r = store.recipe(m.1.recipeID) { return JoeReply(text: "Ce soir : \(r.title). \(DuoSchedule.cook(on: Date()).map { "\($0.rawValue) est libre plus tôt, c'est son tour." } ?? "")") }
            if let r = store.suggestions.first { return JoeReply(text: "Rien de prévu. Avec ce que vous avez, je propose : \(r.title) (\(r.preparation + r.cooking) min).") }
        }
        let old = DuoAssistant.answer(question, records: store.records, recipes: Catalog.recipes, stock: store.foods, exclusions: store.exclusions)
        if case .addShopping(let i)? = old.action { return JoeReply(text: old.message, action: .shopping(name: i.name)) }
        return JoeReply(text: old.message)
    }

    // MARK: Apple Intelligence (sur l'iPhone, gratuit, hors ligne)
    static var aiAvailable: Bool { ChefAI.isAvailable }

    static func ai(_ question: String, store: AppStore) async -> JoeReply? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            do {
                let session = LanguageModelSession(instructions: instructions(store))
                let prompt = "Contexte de l'app :\n\(context(store))\n\nMessage de \(store.me.rawValue) : \(question)"
                let out = try await session.respond(to: prompt, generating: JoeOutput.self).content
                var reply = JoeReply(text: out.reponse.trimmingCharacters(in: .whitespacesAndNewlines), usedAI: true)
                let title = out.titre.trimmingCharacters(in: .whitespacesAndNewlines)
                switch out.action {
                case "tache" where !title.isEmpty: reply.action = .task(title: title, inDays: max(0, min(60, out.jours)), person: nil)
                case "course" where !title.isEmpty: reply.action = .shopping(name: title)
                case "depense" where !title.isEmpty && out.montant > 0: reply.action = .expense(title: title, cents: Int((out.montant * 100).rounded()), shared: true)
                case "rendezvous" where !title.isEmpty:
                    let day = Calendar.current.date(byAdding: .day, value: max(0, min(365, out.jours)), to: Date()) ?? Date()
                    let h = (0...23).contains(out.heure) ? out.heure : 9
                    reply.action = .event(title: title, start: Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: day) ?? day)
                default: break
                }
                return reply.text.isEmpty ? nil : reply
            } catch { return nil }
        }
        #endif
        return nil
    }

    // MARK: Petits outils de lecture
    static func amount(in s: String) -> Int? {
        let pattern = #"(\d+(?:[.,]\d{1,2})?)\s*(?:€|euros?|eur)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let r = Range(m.range(at: 1), in: s) else { return nil }
        return ManualBudget.amountInCents(String(s[r]))
    }
    static func dayOffset(_ q: String) -> Int? {
        if q.contains("apres demain") || q.contains("apres-demain") { return 2 }
        if q.contains("demain") { return 1 }
        if q.contains("aujourd") || q.contains("ce soir") { return 0 }
        let days = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        for (i, d) in days.enumerated() where q.contains(d) {
            let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7  // lundi = 0
            var n = (i - today + 7) % 7; if n == 0 { n = 7 }; return n
        }
        if q.contains("semaine prochaine") { return 7 }
        return nil
    }
    static func hour(in q: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: #"(\d{1,2})\s*h"#), let m = re.firstMatch(in: q, range: NSRange(q.startIndex..., in: q)), let r = Range(m.range(at: 1), in: q), let h = Int(q[r]), (0...23).contains(h) else { return nil }
        return h
    }
    static func minutes(in q: String) -> Int {
        guard let re = try? NSRegularExpression(pattern: #"\d{1,2}\s*h\s*(\d{2})"#), let m = re.firstMatch(in: q, range: NSRange(q.startIndex..., in: q)), let r = Range(m.range(at: 1), in: q), let v = Int(q[r]), (0...59).contains(v) else { return 0 }
        return v
    }
    static func stripDate(_ s: String) -> String {
        var t = s
        for w in ["apres-demain", "apres demain", "après-demain", "demain", "aujourd'hui", "aujourd hui", "ce soir", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche", "semaine prochaine", " a ", " à "] { t = t.replacingOccurrences(of: w, with: " ", options: .caseInsensitive) }
        if let re = try? NSRegularExpression(pattern: #"\d{1,2}\s*h\s*\d{0,2}"#) { t = re.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ") }
        return t.split(whereSeparator: { $0 == " " }).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
    static func cleanItem(_ s: String) -> String {
        var t = " " + s + " "
        for w in [" du ", " de la ", " des ", " de l ", " le ", " la ", " les ", " un ", " une ", " de "] { t = t.replacingOccurrences(of: w, with: " ") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct JoeOutput {
    @Guide(description: "Réponse en français, tutoiement, 1 à 4 phrases concrètes")
    var reponse: String
    @Guide(description: "Action proposée : aucune, tache, course, depense ou rendezvous")
    var action: String
    @Guide(description: "Titre court de l'élément à ajouter, vide si aucune action")
    var titre: String
    @Guide(description: "Montant en euros pour une dépense, sinon 0")
    var montant: Double
    @Guide(description: "Dans combien de jours, 0 pour aujourd'hui")
    var jours: Int
    @Guide(description: "Heure du rendez-vous de 0 à 23, ou -1 si inconnue")
    var heure: Int
}
#endif

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
