import XCTest
@testable import CCProxy

final class ProductMetadataTests: XCTestCase {
    func testBundleIdentifierIsCorrect() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String,
            "com.devnewbie1826.ccproxy"
        )
    }

    func testShortVersionStringIsBaseline() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            "0.1.0"
        )
    }

    func testBundleNameIsCCProxy() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
            "CCProxy"
        )
    }

    func testSUFeedURLUsesCanonicalRepo() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            "https://raw.githubusercontent.com/DevNewbie1826/ccproxy/main/appcast.xml"
        )
    }

    func testBundleVersionIsBaseline() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            "1"
        )
    }
}
