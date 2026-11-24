import Foundation
import DUOCore

struct AuthSession: Codable {
    struct User: Codable { let id: UUID }
    let access_token: String; let refresh_token: String; let expires_at: Double?; let user: User
}
@MainActor final class Backend {
    var session: AuthSession?
    let base: URL; let key: String
    init() throws {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, let url = URL(string: raw), url.scheme == "https", let host = url.host, host.hasSuffix(".supabase.co"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String, !key.isEmpty, !key.contains("$("), !key.hasPrefix("sb_secret_") else { throw DuoError.invalid("Synchronisation non configurée. Le mode local reste disponible.") }
        base = url; self.key = key
        if let data = try Keychain.read() { session = try JSONDecoder().decode(AuthSession.self, from: data) }
    }
    func request(_ path: String, method: String = "POST", body: Data? = nil, authenticated: Bool = true, bearerToken: String? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL,
              url.scheme == "https", url.host == base.host, url.port == base.port,
              url.user == nil, url.password == nil
        else { throw DuoError.invalid("Adresse du service non autorisée.") }
        // Never send a bearer token to an origin other than this Supabase project.
        var r = URLRequest(url: url); r.httpMethod = method; r.httpBody = body; r.timeoutInterval = 25
        r.setValue(key, forHTTPHeaderField: "apikey"); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated { guard let token = bearerToken ?? session?.access_token else { throw DuoError.unauthorized }; r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw DuoError.invalid("Réponse réseau invalide.") }
        if http.statusCode == 401 { throw DuoError.unauthorized }
        if http.statusCode == 409 { throw DuoError.conflict }
        guard (200..<300).contains(http.statusCode) else { throw DuoError.invalid("Le service a refusé l’opération (\(http.statusCode)). Vérifiez vos informations et réessayez.") }
        return data
    }
    func login(email: String, password: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await request("/auth/v1/token?grant_type=password", body: body, authenticated: false)
        let value = try JSONDecoder().decode(AuthSession.self, from: data); try Keychain.save(data); session = value
    }
    func signup(email: String, password: String) async throws {
        guard password.count >= 12 else { throw DuoError.invalid("Utilisez au moins 12 caractères.") }
        _ = try await request("/auth/v1/signup", body: JSONSerialization.data(withJSONObject: ["email":email,"password":password]), authenticated: false)
    }
    func requestPasswordReset(email: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.count <= 254 else { throw DuoError.invalid("Saisissez une adresse e-mail valide.") }
        _ = try await request("/auth/v1/recover", body: JSONSerialization.data(withJSONObject: ["email": trimmed]), authenticated: false)
    }
    func completePasswordReset(email: String, token: String, newPassword: String) async throws {
        guard newPassword.count >= 12 else { throw DuoError.invalid("Le nouveau mot de passe doit comporter au moins 12 caractères.") }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6, trimmed.count <= 8, trimmed.allSatisfy({ $0.isNumber }) else { throw DuoError.invalid("Saisissez le code numérique reçu par e-mail.") }
        let data = try await request("/auth/v1/verify", body: JSONSerialization.data(withJSONObject: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "token": trimmed, "type": "recovery"]), authenticated: false)
        let recoverySession = try JSONDecoder().decode(AuthSession.self, from: data)
        _ = try await request("/auth/v1/user", method: "PUT", body: JSONSerialization.data(withJSONObject: ["password": newPassword]), bearerToken: recoverySession.access_token)
        // Recovery credentials remain temporary; do not save them in Keychain.
        _ = try? await request("/auth/v1/logout", bearerToken: recoverySession.access_token)
    }
    func deleteMyAccount() async throws {
        guard session != nil else { throw DuoError.unauthorized }
        // The Edge Function verifies the JWT, erases the data transactionally, then
        // deletes the Auth identity with a server-side service role secret.
        _ = try await request("/functions/v1/delete-account", body: Data("{}".utf8))
        Keychain.clear(); session = nil
    }
    func refresh() async throws {
        guard let s = session else { throw DuoError.unauthorized }
        let data = try await request("/auth/v1/token?grant_type=refresh_token", body: JSONSerialization.data(withJSONObject: ["refresh_token":s.refresh_token]), authenticated: false)
        let value = try JSONDecoder().decode(AuthSession.self, from: data); try Keychain.save(data); session = value
    }
    func rpc<T: Decodable>(_ name: String, _ body: [String: Any] = [:], as type: T.Type) async throws -> T {
        let data = try await request("/rest/v1/rpc/" + name, body: JSONSerialization.data(withJSONObject: body))
        return try JSONDecoder().decode(T.self, from: data)
    }
    func household() async throws -> UUID? {
        struct Member: Decodable { let household_id: UUID }
        let data = try await request("/rest/v1/members?select=household_id", method: "GET")
        return try JSONDecoder().decode([Member].self, from: data).first?.household_id
    }
    func fetch() async throws -> [Record] {
        // RPC returns a complete bounded household snapshot, avoiding PostgREST's default 1000-row pagination truncation.
        try await rpc("read_records", as: [Record].self)
    }
    func push(_ rows: [Record]) async throws -> [Record] {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rows))
        return try await rpc("apply_records", ["p_rows": object], as: [Record].self)
    }
    func askAI(question: String) async throws -> String {
        let value = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 800 else { throw DuoError.invalid("Question vide ou trop longue.") }
        // Only the text explicitly submitted by the user is transmitted. Never the snapshot,
        // calendars, session tokens or household ID (authentication is sent in the HTTP header).
        let payload = try JSONSerialization.data(withJSONObject: ["question": value])
        struct Answer: Decodable { let answer: String }
        let response = try await request("/functions/v1/duo-assistant", body: payload)
        let answer = try JSONDecoder().decode(Answer.self, from: response).answer
        guard !answer.isEmpty, answer.count <= 4000 else { throw DuoError.invalid("Réponse IA invalide.") }
        return answer
    }
    func logout() async { _ = try? await request("/auth/v1/logout"); Keychain.clear(); session = nil }
}
