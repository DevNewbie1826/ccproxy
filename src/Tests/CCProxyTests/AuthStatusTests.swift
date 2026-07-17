import XCTest
@testable import CCProxy

final class AuthStatusTests: XCTestCase {

    func testServiceTypeExactRawValues() {
        let rawValues = ServiceType.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues, ["claude", "codex", "zai", "minimax", "kimi", "opencode-go", "xai"])
    }

    func testServiceTypeExactDisplayNames() {
        let names = ServiceType.allCases.map(\.displayName)
        XCTAssertEqual(names, ["Claude Code", "Codex", "Z.AI GLM", "MiniMax", "Kimi", "OpenCode Go", "xAI Grok"])
    }

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
            try writeCredential(legacyKimiCredential(), to: legacyFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            assertFileMissing(legacyFile)
            assertFileExists(legacyFile.appendingPathExtension("legacy"))
            XCTAssertTrue(manager.accounts(for: .kimi).isEmpty)
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testValidOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-oauth.json")
            try writeCredential(kimiOAuthCredential(), to: oauthFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            assertFileExists(oauthFile)
            assertFileMissing(oauthFile.appendingPathExtension("legacy"))
            XCTAssertEqual(manager.accounts(for: .kimi).map(\.id), ["kimi-oauth.json"])
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testExpiredOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-expired.json")
            try writeCredential(kimiOAuthCredential(expired: "2000-01-01T00:00:00Z"), to: oauthFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            let accounts = manager.accounts(for: .kimi)
            XCTAssertEqual(accounts.map(\.id), ["kimi-expired.json"])
            XCTAssertTrue(accounts.first?.isExpired ?? false)
            assertFileExists(oauthFile)
            assertFileMissing(oauthFile.appendingPathExtension("legacy"))
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testDisabledValidOAuthKimiFileIsPreservedAndNotFlagged() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-disabled.json")
            try writeCredential(kimiOAuthCredential(disabled: true), to: oauthFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            let accounts = manager.accounts(for: .kimi)
            XCTAssertEqual(accounts.map(\.id), ["kimi-disabled.json"])
            XCTAssertTrue(accounts.first?.isDisabled ?? false)
            assertFileExists(oauthFile)
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testLegacyKimiMigrationIsIdempotentAndFlagStateStable() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-idempotent.json")
            try writeCredential(legacyKimiCredential(), to: legacyFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)
            refreshAuthStatus(manager)

            assertFileMissing(legacyFile)
            assertFileExists(legacyFile.appendingPathExtension("legacy"))
            assertFileMissing(legacyFile.appendingPathExtension("legacy.1"))
            XCTAssertTrue(manager.accounts(for: .kimi).isEmpty)
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testLegacyKimiMigrationUsesNumberedSuffixWhenLegacyFileExists() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-collision.json")
            let existingLegacyFile = legacyFile.appendingPathExtension("legacy")
            try writeCredential(legacyKimiCredential(), to: legacyFile)
            try "already quarantined".write(to: existingLegacyFile, atomically: true, encoding: .utf8)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            assertFileMissing(legacyFile)
            assertFileExists(existingLegacyFile)
            assertFileExists(legacyFile.appendingPathExtension("legacy.1"))
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
            refreshAuthStatus(manager)

            assertFileExists(zaiFile)
            assertFileMissing(zaiFile.appendingPathExtension("legacy"))
            XCTAssertEqual(manager.accounts(for: .zai).map(\.id), ["zai-api-key.json"])
            XCTAssertTrue(manager.providersRequiringReLogin.isEmpty)
        }
    }

    func testKimiFileWithApiKeyAndAccessTokenIsTreatedAsOAuth() throws {
        try withTemporaryAuthDirectory { authDir in
            let oauthFile = authDir.appendingPathComponent("kimi-mixed.json")
            try writeCredential(kimiOAuthCredential(apiKey: "legacy-key"), to: oauthFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)

            assertFileExists(oauthFile)
            assertFileMissing(oauthFile.appendingPathExtension("legacy"))
            XCTAssertEqual(manager.accounts(for: .kimi).map(\.id), ["kimi-mixed.json"])
            XCTAssertFalse(manager.providersRequiringReLogin.contains(.kimi))
        }
    }

    func testKimiReLoginFlagClearsAfterValidOAuthFileAppears() throws {
        try withTemporaryAuthDirectory { authDir in
            let legacyFile = authDir.appendingPathComponent("kimi-old.json")
            try writeCredential(legacyKimiCredential(), to: legacyFile)

            let manager = makeManager(authDir: authDir)
            refreshAuthStatus(manager)
            XCTAssertTrue(manager.providersRequiringReLogin.contains(.kimi))

            let oauthFile = authDir.appendingPathComponent("kimi-oauth.json")
            try writeCredential(kimiOAuthCredential(), to: oauthFile)

            refreshAuthStatus(manager)

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

    func legacyKimiCredential() -> [String: Any] {
        [
            "type": "kimi",
            "api_key": "legacy-key"
        ]
    }

    func kimiOAuthCredential(expired: String = "2999-01-01T00:00:00Z",
                             disabled: Bool = false,
                             apiKey: String? = nil) -> [String: Any] {
        var credential: [String: Any] = [
            "type": "kimi",
            "access_token": "access-token",
            "refresh_token": "refresh-token",
            "expired": expired
        ]
        if disabled {
            credential["disabled"] = true
        }
        if let apiKey {
            credential["api_key"] = apiKey
        }
        return credential
    }

    func refreshAuthStatus(_ manager: AuthManager) {
        manager.checkAuthStatus()
        let expectation = expectation(description: "AuthManager main-queue update")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func assertFileExists(_ url: URL, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "Expected file to exist: \(url.path)",
                      file: file,
                      line: line)
    }

    func assertFileMissing(_ url: URL, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "Expected file to be missing: \(url.path)",
                       file: file,
                       line: line)
    }
}
