import Foundation
import Security
import DUOCore

struct DiskStore {
    let url: URL
    init(scope: String) throws {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("DUO", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(scope + ".json")
    }
    static func deleteCaches(for user: UUID) throws {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("DUO", isDirectory: true)
        guard FileManager.default.fileExists(atPath: base.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) {
            // Exact UUID prefix prevents removing another account or the local mode.
            if file.lastPathComponent.hasPrefix(user.uuidString + "-") && file.pathExtension == "json" {
                try FileManager.default.removeItem(at: file)
            }
        }
    }
    func read() throws -> Snapshot? { guard FileManager.default.fileExists(atPath: url.path) else { return nil }; return try Snapshot.decode(Data(contentsOf: url)) }
    func write(_ snapshot: Snapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var resource = url; var values = URLResourceValues(); values.isExcludedFromBackup = true; try resource.setResourceValues(values)
    }
}
struct Keychain {
    static let service = "DUO.session"
    static func save(_ data: Data) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "supabase"]
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound { var insert = query; attributes.forEach { insert[$0.key] = $0.value }; guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw DuoError.invalid("Impossible de protéger la session.") } }
        else if update != errSecSuccess { throw DuoError.invalid("Impossible de mettre à jour la session.") }
    }
    static func read() throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "supabase", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw DuoError.invalid("Déverrouillez l’iPhone pour accéder à la session.") }; return result as? Data
    }
    static func clear() { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary) }
}

/// Keeps a received invitation through email verification or an app restart.
/// The token is never synced to iCloud, and is not used for automatic joining.
enum InviteVault {
    private static let service = "DUO.pending-invite"
    private struct Saved: Codable { let token: String; let receivedAt: Date }
    static func save(_ token: String) throws {
        guard InviteLink.valid(token) else { throw DuoError.invalid("Invitation non reconnue.") }
        let bytes = try JSONEncoder().encode(Saved(token: token, receivedAt: Date()))
        clear()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "invitation",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: bytes]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw DuoError.invalid("Impossible de conserver l’invitation de manière sécurisée.")
        }
    }
    static func load() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "invitation",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var raw: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &raw) == errSecSuccess,
              let data = raw as? Data,
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              Date().timeIntervalSince(saved.receivedAt) < 24 * 3600,
              InviteLink.valid(saved.token) else { return nil }
        return saved.token
    }
    static func clear() {
        _ = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service] as CFDictionary)
    }
}
