import XCTest
@testable import CCProxy

final class AuthStatusTests: XCTestCase {
    func testServiceTypeIncludesKimi() {
        XCTAssertTrue(ServiceType.allCases.contains(.kimi))
    }
}
