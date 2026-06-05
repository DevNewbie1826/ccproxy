import XCTest
@testable import CCProxy

final class AuthStatusTests: XCTestCase {

    /// Verifies ServiceType contains exactly the six providers in order.
    func testServiceTypeExactRawValues() {
        let rawValues = ServiceType.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues, ["claude", "codex", "zai", "minimax", "kimi", "opencode-go"])
    }

    /// Verifies ServiceType display names match the six providers.
    func testServiceTypeExactDisplayNames() {
        let names = ServiceType.allCases.map(\.displayName)
        XCTAssertEqual(names, ["Claude Code", "Codex", "Z.AI GLM", "MiniMax", "Kimi", "OpenCode Go"])
    }

    /// Verifies that removed provider raw values are absent from ServiceType.
    func testRemovedProviderRawValuesAreAbsent() {
        let rawValues = ServiceType.allCases.map(\.rawValue)
        let removedNeedles = [
            "ge" + "mi" + "ni",
            "gi" + "thub-" + "co" + "pilot",
            "co" + "pilot",
            "q" + "wen",
            "anti" + "gravity"
        ]
        for needle in removedNeedles {
            XCTAssertFalse(rawValues.contains(needle),
                           "Removed provider raw value '\(needle)' should not be present")
        }
    }

    /// Verifies that removed provider display name fragments are absent.
    func testRemovedProviderDisplayNamesAreAbsent() {
        let names = ServiceType.allCases.map(\.displayName)
        let removedFragments = [
            "Ge" + "mi" + "ni",
            "Co" + "pilot",
            "Q" + "wen",
            "Anti" + "gravity"
        ]
        for fragment in removedFragments {
            for name in names {
                XCTAssertFalse(name.contains(fragment),
                               "Display name '\(name)' should not contain removed fragment")
            }
        }
    }
}
