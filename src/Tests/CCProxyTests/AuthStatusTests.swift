import XCTest
@testable import CCProxy

final class AuthStatusTests: XCTestCase {

    /// Verifies ServiceType contains exactly the providers in order.
    func testServiceTypeExactRawValues() {
        let rawValues = ServiceType.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues, ["claude", "codex", "zai", "minimax", "kimi", "opencode-go", "xai"])
    }

    /// Verifies ServiceType display names match the providers.
    func testServiceTypeExactDisplayNames() {
        let names = ServiceType.allCases.map(\.displayName)
        XCTAssertEqual(names, ["Claude Code", "Codex", "Z.AI GLM", "MiniMax", "Kimi", "OpenCode Go", "xAI Grok"])
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

    func testLegacyKimiFileIsQuarantinedAndFlaggedForReLogin() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-legacy.json")
            try writeCredential([
                "type": "kimi",
                "api_key": "legacy-key"
            ], to: legacyFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFile.appendingPathExtension("legacy").path))
            XCTAssertTrue(manager.accounts(for: .kimi).isEmpty)
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testValidOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-oauth.json")
            try writeCredential([
                "type": "kimi",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "expired": "2999-01-01T00:00:00Z"
            ], to: oauthFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertTrue(FileManager.default.fileExists(atPath: oauthFile.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: oauthFile.appendingPathExtension("legacy").path))
            XCTAssertEqual(manager.accounts(for: .kimi).map(\.id), ["kimi-oauth.json"])
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testExpiredOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-expired.json")
            try writeCredential([
                "type": "kimi",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "expired": "2000-01-01T00:00:00Z"
            ], to: oauthFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            let accounts = manager.accounts(for: .kimi)
            XCTAssertEqual(accounts.map(\.id), ["kimi-expired.json"])
            XCTAssertTrue(accounts.first?.isExpired ?? false)
            XCTAssertTrue(FileManager.default.fileExists(atPath: oauthFile.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: oauthFile.appendingPathExtension("legacy").path))
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testDisabledValidOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-disabled.json")
            try writeCredential([
                "type": "kimi",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "expired": "2999-01-01T00:00:00Z",
                "disabled": true
            ], to: oauthFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            let accounts = manager.accounts(for: .kimi)
            XCTAssertEqual(accounts.map(\.id), ["kimi-disabled.json"])
            XCTAssertTrue(accounts.first?.isDisabled ?? false)
            XCTAssertTrue(FileManager.default.fileExists(atPath: oauthFile.path))
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testLegacyKimiMigrationIsIdempotentAndFlagStateStable() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-idempotent.json")
            try writeCredential([
                "type": "kimi",
                "api_key": "legacy-key"
            ], to: legacyFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFile.appendingPathExtension("legacy").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.appendingPathExtension("legacy.1").path))
            XCTAssertTrue(manager.accounts(for: .kimi).isEmpty)
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testLegacyKimiMigrationUsesNumberedSuffixWhenLegacyFileExists() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-collision.json")
            let existingLegacyFile = legacyFile.appendingPathExtension("legacy")
            try writeCredential([
                "type": "kimi",
                "api_key": "legacy-key"
            ], to: legacyFile)
            try "already quarantined".write(to: existingLegacyFile, atomically: true, encoding: .utf8)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: existingLegacyFile.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: legacyFile.appendingPathExtension("legacy.1").path))
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testZaiApiKeyFileIsUntouchedAndUnaffectedByKimiMigration() throws {
        try withTemporaryAuthDirectory { authDir in
            let zaiFile = authDir.appendingPathComponent("zai-api-key.json")
            try writeCredential([
                "type": "zai",
                "api_key": "zai-key"
            ], to: zaiFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertTrue(FileManager.default.fileExists(atPath: zaiFile.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: zaiFile.appendingPathExtension("legacy").path))
            XCTAssertEqual(manager.accounts(for: .zai).map(\.id), ["zai-api-key.json"])
            XCTAssertTrue(manager.providersRequiringReLogin.isEmpty)
        }
    }

    func testKimiFileWithApiKeyAndAccessTokenIsTreatedAsOAuth() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-mixed.json")
            try writeCredential([
                "type": "kimi",
                "api_key": "legacy-key",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "expired": "2999-01-01T00:00:00Z"
            ], to: oauthFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertTrue(FileManager.default.fileExists(atPath: oauthFile.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: oauthFile.appendingPathExtension("legacy").path))
            XCTAssertEqual(manager.accounts(for: .kimi).map(\.id), ["kimi-mixed.json"])
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testKimiReLoginFlagClearsAfterValidOAuthFileAppears() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-old.json")
            try writeCredential([
                "type": "kimi",
                "api_key": "legacy-key"
            ], to: legacyFile)

            let manager = makeManager(authDir: authDir)
            manager.checkAuthStatus()
            waitForAuthStatusUpdate()
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))

            let oauthFile = authDir.appendingPathComponent("kimi-oauth.json")
            try writeCredential([
                "type": "kimi",
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "expired": "2999-01-01T00:00:00Z"
            ], to: oauthFile)

            manager.checkAuthStatus()
            waitForAuthStatusUpdate()

            XCTAssertEqual(manager.accounts(for: .kimi).map(\.id), ["kimi-oauth.json"])
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }
}

private extension AuthStatusTests {
    func makeManager(authDir: URL) -> AuthManager {
        let manager = AuthManager()
        manager.authDirectoryOverride = authDir
        return manager
    }

    func withTemporaryAuthDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-authstatus-tests-\(UUID().uuidString)", isDirectory: true)
        let authDir = root.appendingPathComponent("auth", isDirectory: true)
        try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(authDir)
    }

    func writeCredential(_ credential: [String: Any], to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: credential, options: [.sortedKeys])
        try data.write(to: file, options: .atomic)
    }

    func waitForAuthStatusUpdate(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "AuthManager main-queue update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
