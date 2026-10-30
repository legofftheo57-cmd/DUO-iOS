import Foundation

/// Validates responses without mutating a device's offline snapshot.
/// Decoding JSON alone does not prove that server acknowledgements are complete.
public enum SyncContract {
    public static func validateFetched(_ rows: [Record], for snapshot: Snapshot) throws {
        guard Set(rows.map(\.id)).count == rows.count else {
            throw DuoError.invalid("Le serveur a renvoyé des identifiants dupliqués. Les données locales sont conservées.")
        }
        for row in rows {
            guard row.householdID == snapshot.householdID,
                  row.ownerID == nil || row.ownerID == snapshot.userID,
                  row.revision > 0 else {
                throw DuoError.invalid("Réponse de synchronisation incorrecte : identité ou révision invalide.")
            }
            try row.payload.validate()
        }
    }

    public static func validateAcknowledged(_ received: [Record], pending: [Record], for snapshot: Snapshot) throws {
        // The server must acknowledge exactly the submitted batch, once each.
        guard received.count == pending.count,
              Set(received.map(\.id)).count == received.count,
              Set(received.map(\.id)) == Set(pending.map(\.id)) else {
            throw DuoError.invalid("Confirmation du serveur incomplète : modifications locales conservées.")
        }
        let originals = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
        for row in received {
            guard let local = originals[row.id],
                  row.householdID == snapshot.householdID,
                  row.ownerID == local.ownerID,
                  row.ownerID == nil || row.ownerID == snapshot.userID,
                  local.revision < Int.max,
                  row.revision == local.revision + 1,
                  row.payload == local.payload,
                  row.deleted == local.deleted else {
                throw DuoError.invalid("Confirmation de synchronisation incohérente : modifications locales conservées.")
            }
            try row.payload.validate()
        }
    }
}
