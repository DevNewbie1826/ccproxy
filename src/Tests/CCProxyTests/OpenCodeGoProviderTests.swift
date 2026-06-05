import XCTest
@testable import CCProxy

final class OpenCodeGoProviderTests: XCTestCase {
    private var originalEnabledProviders: Any?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        originalEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "enabledProviders")
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        if let saved = originalEnabledProviders {
            defaults.set(saved, forKey: "enabledProviders")
        } else {
            defaults.removeObject(forKey: "enabledProviders")
        }
        defaults.synchronize()
        originalEnabledProviders = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    /// Saving an OpenCode Go key writes one 0o600 JSON credential under the
    /// isolated auth directory with type "opencode-go", api_key "opencode-test-key",
    /// no key in the filename, and no source-controlled secret.
    func testSaveOpenCodeGoApiKeyWritesCredentialFile() {
        withTemporaryAuthDirectory { authDir in
            let manager = makeManager(authDir: authDir)
            let expectation = self.expectation(description: "Save completion")

            manager.saveOpenCodeGoApiKey("opencode-test-key") { success, _ in
                XCTAssertTrue(success, "Save should succeed")
                expectation.fulfill()
            }

            waitForExpectations(timeout: 2.0)

            // Verify exactly one JSON credential file was created
            let files = try! FileManager.default.contentsOfDirectory(
                at: authDir, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            XCTAssertEqual(jsonFiles.count, 1,
                           "Should create exactly one credential file, found: \(jsonFiles)")

            let file = jsonFiles[0]

            // Verify filename does not contain the API key
            XCTAssertFalse(file.lastPathComponent.contains("opencode-test-key"),
                           "Filename must not contain the API key")

            // Verify file permissions are 0o600
            let attrs = try! FileManager.default.attributesOfItem(atPath: file.path)
            let perms = attrs[.posixPermissions] as! UInt
            XCTAssertEqual(perms, 0o600,
                           "Credential file should have 0o600 permissions")

            // Verify JSON content
            let data = try! Data(contentsOf: file)
            let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            XCTAssertEqual(json["type"] as? String, "opencode-go",
                           "Credential type must be opencode-go")
            XCTAssertEqual(json["api_key"] as? String, "opencode-test-key",
                           "Credential must contain the exact API key")
        }
    }

    // MARK: - Connected-Provider Tests

    /// Connected-provider calculation includes opencode-go only when the provider
    /// is enabled and the isolated auth directory contains at least one non-disabled
    /// credential file/account with type "opencode-go" and a non-empty api_key.
    func testConnectedProviderIncludesOpenCodeGoWhenEnabledWithValidKey() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "valid-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders()

            XCTAssertTrue(connected.contains(.opencodeGo),
                          "opencode-go should be connected when enabled with valid key")
        }
    }

    /// Connected-provider calculation excludes opencode-go when the provider
    /// is enabled but no credential file exists.
    func testConnectedProviderExcludesOpenCodeGoWhenNoCredential() {
        withTemporaryAuthDirectory { authDir in
            // No credential files written

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders()

            XCTAssertFalse(connected.contains(.opencodeGo),
                           "opencode-go should be excluded when no credential exists")
        }
    }

    /// Connected-provider calculation excludes opencode-go when the only
    /// credential has an empty API key.
    func testConnectedProviderExcludesOpenCodeGoWhenEmptyKey() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders()

            XCTAssertFalse(connected.contains(.opencodeGo),
                           "opencode-go should be excluded when API key is empty")
        }
    }

    /// Connected-provider calculation excludes opencode-go when the only
    /// credential/account is marked disabled.
    func testConnectedProviderExcludesOpenCodeGoWhenDisabledCredential() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "valid-key",
                            disabled: true, authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders()

            XCTAssertFalse(connected.contains(.opencodeGo),
                           "opencode-go should be excluded when credential is disabled")
        }
    }

    /// Connected-provider calculation excludes opencode-go when the provider
    /// is disabled even if a valid credential file exists.
    func testConnectedProviderExcludesOpenCodeGoWhenProviderDisabled() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "valid-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["opencode-go"] = false

            let connected = manager.connectedProviders()

            XCTAssertFalse(connected.contains(.opencodeGo),
                           "opencode-go should be excluded when provider is disabled")
        }
    }

    // MARK: - Config Exclusion Tests

    /// Generated config must not emit a claude-api-key block for opencode-go
    /// when the only credential is disabled.
    func testConfigExcludesOpenCodeGoWhenCredentialDisabled() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "valid-key",
                            disabled: true, authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = self.readConfig(at: configPath) else { return }

            XCTAssertFalse(contents.contains("api-key: \"valid-key\""),
                           "Config must not contain disabled opencode-go credential key")
            XCTAssertFalse(contents.contains("prefix: \"opencode-go\""),
                           "Config must not emit opencode-go block for disabled credential")
        }
    }

    /// Generated config must not emit a claude-api-key block for opencode-go
    /// when the only credential has an empty API key.
    func testConfigExcludesOpenCodeGoWhenEmptyApiKey() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = self.readConfig(at: configPath) else { return }

            XCTAssertFalse(contents.contains("prefix: \"opencode-go\""),
                           "Config must not emit opencode-go block for empty API key")
        }
    }

    /// Generated config must not emit a claude-api-key block for opencode-go
    /// when the provider is disabled even though a valid credential exists.
    func testConfigExcludesOpenCodeGoWhenProviderDisabled() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "valid-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["opencode-go"] = false

            let configPath = manager.getConfigPath()

            guard let contents = self.readConfig(at: configPath) else { return }

            XCTAssertFalse(contents.contains("api-key: \"valid-key\""),
                           "Config must not contain opencode-go key when provider disabled")
            XCTAssertFalse(contents.contains("prefix: \"opencode-go\""),
                           "Config must not emit opencode-go block when provider disabled")
        }
    }

    // MARK: - Type-Mismatch Tests

    /// A file named opencode-go-*.json whose JSON type is another provider must
    /// be ignored for OpenCode Go connected-provider calculation. The JSON type
    /// field determines provider identity; connectedProviders categorizes by
    /// JSON type, so the credential counts toward the actual type's provider.
    func testConnectedProviderIgnoresMismatchedTypeForOpenCodeGo() {
        withTemporaryAuthDirectory { authDir in
            // File has opencode-go prefix in filename but type is "zai"
            writeMismatchedCredential(filenamePrefix: "opencode-go",
                                      actualType: "zai",
                                      apiKey: "zai-key-in-ocg-file",
                                      authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders()

            XCTAssertFalse(connected.contains(.opencodeGo),
                           "opencode-go should be excluded when file has mismatched type")
        }
    }

    /// A file named opencode-go-*.json whose JSON type is another provider must
    /// be routed to that provider's block, not the opencode-go block.
    /// JSON type is authoritative, not the filename prefix.
    func testConfigIgnoresMismatchedTypeForOpenCodeGo() {
        withTemporaryAuthDirectory { authDir in
            // File has opencode-go prefix in filename but type is "zai"
            writeMismatchedCredential(filenamePrefix: "opencode-go",
                                      actualType: "zai",
                                      apiKey: "zai-key-in-ocg-file",
                                      authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = self.readConfig(at: configPath) else { return }

            // The key should NOT appear under the opencode-go prefix (wrong provider)
            // but MAY appear under the zai prefix (correct JSON type)
            XCTAssertFalse(contents.contains("prefix: \"opencode-go\""),
                           "Config must not emit opencode-go block for mismatched type file")
        }
    }
}

// MARK: - Test Helpers

extension OpenCodeGoProviderTests {
    private func makeManager(authDir: URL) -> ServerManager {
        let fixtureConfigPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/config.yaml")
            .path
        let manager = ServerManager()
        manager.bundledConfigPathOverride = fixtureConfigPath
        manager.authDirectoryOverride = authDir
        return manager
    }

    private func withTemporaryAuthDirectory(_ body: (URL) -> Void) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-opencodego-tests-\(UUID().uuidString)", isDirectory: true)
        let authDir = root.appendingPathComponent("auth", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        } catch {
            XCTFail("Failed to create isolated auth directory: \(error)")
            return
        }
        defer { try? FileManager.default.removeItem(at: root) }
        body(authDir)
    }

    private func writeCredential(provider: String, apiKey: String,
                                 disabled: Bool = false, authDir: URL) {
        let file = authDir.appendingPathComponent("\(provider)-test-\(UUID().uuidString).json")
        var credential: [String: Any] = [
            "type": provider,
            "email": "test",
            "api_key": apiKey,
            "created": "2026-04-01T00:00:00Z"
        ]
        if disabled {
            credential["disabled"] = true
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("Failed to write credential for \(provider): \(error)")
        }
    }

    private func writeMismatchedCredential(filenamePrefix: String, actualType: String,
                                             apiKey: String, authDir: URL) {
        let file = authDir.appendingPathComponent("\(filenamePrefix)-mismatch-\(UUID().uuidString).json")
        let credential: [String: Any] = [
            "type": actualType,
            "email": "test",
            "api_key": apiKey,
            "created": "2026-04-01T00:00:00Z"
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("Failed to write mismatched credential: \(error)")
        }
    }

    private func readConfig(at path: String) -> String? {
        do {
            return try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            XCTFail("Failed to read generated config: \(error)")
            return nil
        }
    }
}
