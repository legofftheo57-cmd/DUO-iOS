import XCTest
@testable import DUOCore

final class SessionRefreshPolicyTests: XCTestCase {
    func testFarFutureSessionDoesNotRefresh() {
        XCTAssertFalse(SessionRefreshPolicy.shouldRefresh(expiresAt: 2000, now: 1000))
    }
    func testNearExpirationRefreshes() {
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: 1080, now: 1000))
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: 1090, now: 1000))
        XCTAssertFalse(SessionRefreshPolicy.shouldRefresh(expiresAt: 1091, now: 1000))
    }
    func testExpiredAndMissingExpirationRefreshes() {
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: 999, now: 1000))
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: nil, now: 1000))
    }
    func testInvalidTimestampsRefreshSafely() {
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: .infinity, now: 1000))
        XCTAssertTrue(SessionRefreshPolicy.shouldRefresh(expiresAt: 2000, now: .nan))
    }
}
