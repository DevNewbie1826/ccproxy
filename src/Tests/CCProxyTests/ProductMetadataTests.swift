import XCTest
@testable import CCProxy

final class ProductMetadataTests: XCTestCase {
    func testAppBundleMetadataIsVerifiedOutsideSwiftPMUnitTests() throws {
        throw XCTSkip("App bundle metadata checks are app/Xcode-specific and are not valid under swift test.")
    }
}
