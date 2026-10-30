import Foundation

/// Refresh access tokens near expiration rather than on every 30-second sync.
/// Access and refresh tokens remain in Keychain on iOS.
public enum SessionRefreshPolicy {
    public static func shouldRefresh(expiresAt: TimeInterval?, now: TimeInterval, margin: TimeInterval = 90) -> Bool {
        guard let expiresAt, expiresAt.isFinite, now.isFinite, margin.isFinite, margin >= 0 else { return true }
        return expiresAt <= now + margin
    }
}
