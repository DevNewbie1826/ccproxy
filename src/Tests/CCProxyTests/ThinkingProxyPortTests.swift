import XCTest
@testable import CCProxy

final class ThinkingProxyPortTests: XCTestCase {
    func testDefaultPortsUseNonConflictingValues() {
        let proxy = ThinkingProxy()
        let manager = ServerManager()

        XCTAssertEqual(proxy.proxyPort, 8317)
        XCTAssertEqual(manager.port, 8328)
    }

    func testRequestAuthorizationRequiresMatchingBearerTokenWhenSecretConfigured() {
        let defaults = UserDefaults.standard
        defaults.set("proxy-secret", forKey: "managementSecretKey")
        defer { defaults.removeObject(forKey: "managementSecretKey") }

        let proxy = ThinkingProxy()

        XCTAssertTrue(proxy.isRequestAuthorized(headers: [("Authorization", "Bearer proxy-secret")]))
        XCTAssertFalse(proxy.isRequestAuthorized(headers: []))
        XCTAssertFalse(proxy.isRequestAuthorized(headers: [("Authorization", "Bearer wrong-secret")]))
    }
}
