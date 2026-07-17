import XCTest
import Yams
@testable import CCProxy

final class ServerManagerConfigTests: XCTestCase {
    private var originalManagementSecretKey: Any?
    private var originalEnabledProviders: Any?

    private var fixtureConfigPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/config.yaml")
            .path
    }

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        originalManagementSecretKey = defaults.object(forKey: "managementSecretKey")
        originalEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "managementSecretKey")
        defaults.removeObject(forKey: "enabledProviders")
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        restoreUserDefault(originalManagementSecretKey, forKey: "managementSecretKey")
        restoreUserDefault(originalEnabledProviders, forKey: "enabledProviders")
        defaults.synchronize()
        originalManagementSecretKey = nil
        originalEnabledProviders = nil
        super.tearDown()
    }

    func testMergedConfigIncludesRemoteManagementSecretWhenSet() {
        UserDefaults.standard.set("test-secret", forKey: "managementSecretKey")

        withTemporaryAuthDirectory { authDir in
            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let document = parseConfig(contents)
            let remoteManagement = document["remote-management"] as? [String: Any]

            XCTAssertEqual(remoteManagement?["secret-key"] as? String, "test-secret")
        }
    }

    func testMergedConfigAddsClaudeCompatibleUpstreamsForGeneratedAPIKeyProviders() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-test-key", authDir: authDir)
            writeCredential(provider: "opencode-go", apiKey: "opencode-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)

            XCTAssertEqual(entries.map { $0["api-key"] as? String }, ["zai-test-key", "minimax-test-key", "opencode-test-key"])
            XCTAssertEqual(entries.map { $0["prefix"] as? String }, ["zai", "minimax", "opencode-go"])
            XCTAssertEqual(entry(withPrefix: "zai", in: entries)?["base-url"] as? String, "https://api.z.ai/api/anthropic")
            XCTAssertEqual(entry(withPrefix: "minimax", in: entries)?["base-url"] as? String, "https://api.minimax.io/anthropic")
            XCTAssertEqual(entry(withPrefix: "opencode-go", in: entries)?["base-url"] as? String, "https://opencode.ai/zen/go/v1/messages")
            XCTAssertNil(entry(withPrefix: "kimi", in: entries), "Kimi credentials should not generate claude-api-key entries in T2")
            XCTAssertTrue(entries.allSatisfy { $0["alias"] == nil })
        }
    }

    func testGeneratedConfigDoesNotContainRequestTimeout() {
        withTemporaryAuthDirectory { authDir in
            let obsoleteTimeoutKey = "request" + "-" + "timeout"
            writeCredential(provider: "zai", apiKey: "timeout-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertFalse(contents.contains(obsoleteTimeoutKey),
                           "Generated config must not contain obsolete timeout key")
        }
    }

    func testGeneratedConfigIncludesForceModelPrefix() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let document = parseConfig(contents)

            XCTAssertEqual(document["force-model-prefix"] as? Bool, true,
                           "Generated config must preserve top-level force-model-prefix: true")
        }
    }

    func testOAuthDisabledProvidersGenerateExclusions() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "oauth-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["claude"] = false
            manager.enabledProviders["codex"] = false
            manager.enabledProviders["kimi"] = false
            manager.enabledProviders["xai"] = false

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let exclusions = oauthExcludedModels(from: contents)

            XCTAssertEqual(exclusions["claude"] as? [String], ["*"],
                           "Disabled 'claude' provider should have wildcard exclusion")
            XCTAssertEqual(exclusions["codex"] as? [String], ["*"],
                           "Disabled 'codex' provider should have wildcard exclusion")
            XCTAssertEqual(exclusions["kimi"] as? [String], ["*"],
                           "Disabled 'kimi' provider should have wildcard exclusion")
            XCTAssertEqual(exclusions["xai"] as? [String], ["*"],
                           "Disabled 'xai' provider should have wildcard exclusion")

            let removedNeedles = [
                "ge" + "mi" + "ni-cli",
                "gi" + "thub-" + "co" + "pilot",
                "q" + "wen",
                "anti" + "gravity"
            ]
            for needle in removedNeedles {
                XCTAssertFalse(contents.contains(needle),
                               "Removed provider key should not appear in generated config")
            }
        }
    }

    func testOAuthProviderKeysContainSupportedOAuthProviders() {
        XCTAssertEqual(ServerManager.oauthProviderKeys, [
            "claude": "claude",
            "codex": "codex",
            "kimi": "kimi",
            "xai": "xai"
        ])
    }

    func testBundledConfigOmitsRetiredEntries() {
        let configPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Resources/config.yaml")
            .path

        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            XCTFail("Bundled config.yaml should be readable")
            return
        }

        let retiredConfigKey = ["generative", "language", "api", "key"].joined(separator: "-")
        XCTAssertFalse(contents.contains(retiredConfigKey),
                       "Bundled config must not contain retired config key")

        let removedNeedles = [
            "ge" + "mi" + "ni",
            "co" + "pilot",
            "q" + "wen",
            "anti" + "gravity"
        ]
        for needle in removedNeedles {
            XCTAssertFalse(contents.lowercased().contains(needle.lowercased()),
                           "Bundled config must not contain removed provider name")
        }
    }

    func testActiveSourceAndTestsDoNotContainRemovedProviderNames() {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let directories = ["Sources", "Tests"]
        let extensions: Set<String> = ["swift", "yaml"]

        var allFiles: [URL] = []
        for dir in directories {
            let dirURL = packageRoot.appendingPathComponent(dir)
            if let enumerator = FileManager.default.enumerator(at: dirURL, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if extensions.contains(url.pathExtension) {
                        allFiles.append(url)
                    }
                }
            }
        }

        let removedNeedles = [
            "ge" + "mi" + "ni",
            "gi" + "thub-" + "co" + "pilot",
            "co" + "pilot",
            "q" + "wen",
            "anti" + "gravity",
            ["generative", "language", "api", "key"].joined(separator: "-")
        ]

        for fileURL in allFiles {
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for needle in removedNeedles {
                XCTAssertFalse(contents.lowercased().contains(needle.lowercased()),
                               "File \(fileURL.lastPathComponent) must not contain removed provider token")
            }
        }
    }

    func testSpecialCharacterApiKeyRoundTrip() {
        let testCases: [(name: String, apiKey: String)] = [
            ("colon", "key:with:colons"),
            ("hash", "key#with#hashes"),
            ("single-quote", "key'with'quotes"),
            ("double-quote", "key\"with\"dquotes"),
            ("backslash", "key\\with\\backslashes"),
            ("leading-spaces", "  keyWithLeadingSpaces"),
            ("trailing-spaces", "keyWithTrailingSpaces  "),
            ("newline", "key\nwith\nnewlines"),
            ("combined", "  k:ey#ha'sh\"quote\\slash\nline  ")
        ]

        for testCase in testCases {
            XCTContext.runActivity(named: "Round-trip for \(testCase.name)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: "zai", apiKey: testCase.apiKey, authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }
                    let apiKeys = claudeAPIKeyEntries(from: contents).compactMap { $0["api-key"] as? String }

                    XCTAssertTrue(apiKeys.contains(testCase.apiKey),
                                  "Generated api-key scalar should round-trip exactly for \(testCase.name)")
                }
            }
        }
    }

    // MARK: - Connected-Provider Tests

    /// Fixed reference date for deterministic expiration tests: 2026-06-01T00:00:00Z.
    private var fixedNow: Date {
        Date(timeIntervalSince1970: 1780272000)
    }

    /// With enabled claude and a non-disabled, non-expired Claude OAuth account file,
    /// the connected-provider set contains claude.
    func testConnectedProviderIncludesClaudeWithValidOAuth() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.claude),
                          "claude should be connected with valid OAuth")
        }
    }

    /// With enabled codex and a non-disabled, non-expired Codex OAuth account file,
    /// the connected-provider set contains codex.
    func testConnectedProviderIncludesCodexWithValidOAuth() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.codex),
                          "codex should be connected with valid OAuth")
        }
    }

    func testConnectedProviderIncludesKimiWithValidOAuthAccessToken() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "kimi", authDir: authDir,
                                 accessToken: "kimi-access-token",
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.kimi),
                          "kimi should be connected with valid OAuth access_token")
        }
    }

    func testConnectedProviderExcludesLegacyKimiWithoutAccessToken() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "kimi", apiKey: "legacy-kimi-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.kimi),
                           "legacy kimi API-key shape must not count as connected OAuth")
        }
    }

    func testConnectedProviderExcludesExpiredKimiOAuth() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "kimi", authDir: authDir,
                                 accessToken: "kimi-access-token",
                                 expired: "2020-01-01T00:00:00Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.kimi),
                           "expired kimi OAuth credential should not be connected")
        }
    }

    func testConnectedProviderExcludesDisabledKimiOAuthAndGeneratesExclusion() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "kimi", authDir: authDir,
                                 accessToken: "kimi-access-token",
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["kimi"] = false

            let connected = manager.connectedProviders(now: fixedNow)
            XCTAssertFalse(connected.contains(.kimi),
                           "disabled kimi provider should not be connected")

            let configPath = manager.getConfigPath()
            guard let contents = readConfig(at: configPath) else { return }
            let exclusions = oauthExcludedModels(from: contents)
            XCTAssertEqual(exclusions["kimi"] as? [String], ["*"],
                           "disabled kimi should be excluded from OAuth models")
        }
    }

    func testConnectedProviderIncludesXAIWithValidOAuthAccessToken() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "xai", authDir: authDir,
                                 accessToken: "xai-access-token",
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.xai),
                          "xai should be connected with valid OAuth access_token")
        }
    }

    func testConnectedProviderExcludesDisabledXAIOAuthAndGeneratesExclusion() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "xai", authDir: authDir,
                                 accessToken: "xai-access-token",
                                 expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["xai"] = false

            let connected = manager.connectedProviders(now: fixedNow)
            XCTAssertFalse(connected.contains(.xai),
                           "disabled xai provider should not be connected")

            let configPath = manager.getConfigPath()
            guard let contents = readConfig(at: configPath) else { return }
            let exclusions = oauthExcludedModels(from: contents)
            XCTAssertEqual(exclusions["xai"] as? [String], ["*"],
                           "disabled xai should be excluded from OAuth models")
        }
    }

    func testSaveKimiApiKeyDoesNotWriteCredentialFile() {
        withTemporaryAuthDirectory { authDir in
            let manager = makeManager(authDir: authDir)
            let expectation = expectation(description: "Kimi save rejected")

            manager.saveKimiApiKey("kimi-api-key") { success, _ in
                XCTAssertFalse(success, "Kimi API-key saving should be unavailable after OAuth migration")
                expectation.fulfill()
            }

            waitForExpectations(timeout: 2.0)

            let files = (try? FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)) ?? []
            let kimiAuthFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("kimi-") }
            XCTAssertTrue(kimiAuthFiles.isEmpty,
                          "Rejected Kimi API-key save must not create kimi auth files")
        }
    }

    /// With enabled claude or codex but no provider-matching OAuth auth file/account,
    /// the connected-provider set excludes that provider.
    func testConnectedProviderExcludesOAuthWhenNoAuthFile() {
        withTemporaryAuthDirectory { authDir in
            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded with no OAuth file")
            XCTAssertFalse(connected.contains(.codex),
                           "codex should be excluded with no OAuth file")
        }
    }

    /// With enabled claude or codex but only disabled OAuth account files,
    /// the connected-provider set excludes that provider.
    func testConnectedProviderExcludesOAuthWhenAllDisabled() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 disabled: true, expired: "2099-12-31T23:59:59Z")
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 disabled: true, expired: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when all accounts disabled")
            XCTAssertFalse(connected.contains(.codex),
                           "codex should be excluded when all accounts disabled")
        }
    }

    /// With enabled claude or codex but only expired OAuth account files whose
    /// metadata expiration is before or equal to an injected fixed current date,
    /// the connected-provider set excludes that provider.
    func testConnectedProviderExcludesOAuthWhenAllExpired() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: "2020-01-01T00:00:00Z")
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 expired: "2026-05-31T23:59:00Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when all accounts expired")
            XCTAssertFalse(connected.contains(.codex),
                           "codex should be excluded when all accounts expired")
        }
    }

    /// OAuth credentials with expiration exactly at the injected now are treated as expired.
    func testConnectedProviderExcludesOAuthWhenExpirationEqualsNow() {
        withTemporaryAuthDirectory { authDir in
            let expiredDate = fixedNow
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let expiredStr = formatter.string(from: expiredDate)

            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: expiredStr)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: expiredDate)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when expired exactly equals now")
        }
    }

    /// With enabled zai, minimax, or opencode-go and at least one matching
    /// non-disabled API-key credential file/account with a non-empty key,
    /// the connected-provider set contains that provider.
    func testConnectedProviderIncludesAPIKeyProviderWithValidKey() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("opencode-go", .opencodeGo)
        ]

        for (rawValue, serviceType) in providers {
            XCTContext.runActivity(named: "API-key provider \(rawValue)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: rawValue, apiKey: "valid-key",
                                    authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let connected = manager.connectedProviders(now: fixedNow)

                    XCTAssertTrue(connected.contains(serviceType),
                                  "\(rawValue) should be connected with valid key")
                }
            }
        }
    }

    /// With enabled zai, minimax, or opencode-go but no matching API-key
    /// credential, the connected-provider set excludes that provider.
    func testConnectedProviderExcludesAPIKeyProviderWithNoMatchingKey() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("opencode-go", .opencodeGo)
        ]

        for (rawValue, serviceType) in providers {
            XCTContext.runActivity(named: "API-key provider \(rawValue)") { _ in
                withTemporaryAuthDirectory { authDir in
                    // No credential files written

                    let manager = makeManager(authDir: authDir)
                    let connected = manager.connectedProviders(now: fixedNow)

                    XCTAssertFalse(connected.contains(serviceType),
                                   "\(rawValue) should be excluded with no credential")
                }
            }
        }
    }

    /// With enabled API-key providers but only disabled credentials,
    /// the connected-provider set excludes them.
    func testConnectedProviderExcludesAPIKeyProviderWithOnlyDisabledCredentials() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("opencode-go", .opencodeGo)
        ]

        for (rawValue, serviceType) in providers {
            XCTContext.runActivity(named: "API-key provider \(rawValue)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: rawValue, apiKey: "valid-key",
                                    disabled: true, authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let connected = manager.connectedProviders(now: fixedNow)

                    XCTAssertFalse(connected.contains(serviceType),
                                   "\(rawValue) should be excluded when only disabled credentials exist")
                }
            }
        }
    }

    /// With enabled API-key providers but only empty-key credentials,
    /// the connected-provider set excludes them.
    func testConnectedProviderExcludesAPIKeyProviderWithOnlyEmptyKeys() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("opencode-go", .opencodeGo)
        ]

        for (rawValue, serviceType) in providers {
            XCTContext.runActivity(named: "API-key provider \(rawValue)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: rawValue, apiKey: "",
                                    authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let connected = manager.connectedProviders(now: fixedNow)

                    XCTAssertFalse(connected.contains(serviceType),
                                   "\(rawValue) should be excluded when only empty keys exist")
                }
            }
        }
    }

    /// With any disabled provider including claude, codex, zai, minimax, kimi,
    /// xai, or opencode-go, the connected-provider set excludes that provider even
    /// when valid auth or API-key credentials exist.
    func testConnectedProviderExcludesDisabledProviderEvenWithValidCredentials() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")
            writeOAuthCredential(provider: "kimi", authDir: authDir,
                                 accessToken: "kimi-access-token",
                                 expired: "2099-12-31T23:59:59Z")
            writeOAuthCredential(provider: "xai", authDir: authDir,
                                 accessToken: "xai-access-token",
                                 expired: "2099-12-31T23:59:59Z")
            writeCredential(provider: "zai", apiKey: "zai-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-key", authDir: authDir)
            writeCredential(provider: "opencode-go", apiKey: "ocg-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            for serviceType in ServiceType.allCases {
                manager.enabledProviders[serviceType.rawValue] = false
            }

            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.isEmpty,
                          "All disabled providers should be excluded even with valid credentials")
        }
    }

    /// A provider configured as no-auth/no-key is excluded from the
    /// connected-provider set even when enabled.
    func testConnectedProviderExcludesNoAuthNoKeyProviderWhenEnabled() {
        withTemporaryAuthDirectory { authDir in
            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.isEmpty,
                          "Providers with no credentials should be excluded even when enabled")
        }
    }

    // MARK: - OpenCode Go Config Tests

    /// With an isolated opencode-go credential, generated config contains one
    /// claude-api-key provider entry with prefix "opencode-go",
    /// base-url "https://opencode.ai/zen/go/v1/messages", and the correct api-key.
    func testOpenCodeGoConfigContainsClaudeApiKeyEntry() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "opencode-test-key",
                            authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let opencodeGoEntry = entry(withPrefix: "opencode-go", in: entries)

            XCTAssertEqual(opencodeGoEntry?["api-key"] as? String, "opencode-test-key",
                           "Config should contain the OpenCode Go API key")
            XCTAssertEqual(opencodeGoEntry?["prefix"] as? String, "opencode-go",
                           "Config should contain opencode-go prefix")
            XCTAssertEqual(opencodeGoEntry?["base-url"] as? String, "https://opencode.ai/zen/go/v1/messages",
                           "Config should contain the messages endpoint as base-url")
        }
    }

    /// With injected OpenCode Go catalog models, generated claude-api-key config
    /// model names are unprefixed slugs; the config must not double-prefix.
    func testOpenCodeGoConfigModelNamesAreUnprefixedSlugs() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "ocg-test-key",
                            authDir: authDir)

            let manager = makeManager(authDir: authDir)
            // Inject provider-qualified catalog model IDs
            manager.catalogModelsOverride = [
                "opencode-go": ["opencode-go/kimi-k2.6", "opencode-go/claude-sonnet-4"]
            ]

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let modelNames = modelNames(in: entry(withPrefix: "opencode-go", in: entries))

            XCTAssertTrue(modelNames.contains("kimi-k2.6"),
                          "Config should contain unprefixed slug kimi-k2.6")
            XCTAssertTrue(modelNames.contains("claude-sonnet-4"),
                          "Config should contain unprefixed slug claude-sonnet-4")

            XCTAssertFalse(modelNames.contains("opencode-go/kimi-k2.6"),
                           "Config must not contain double-prefixed model names")
            XCTAssertFalse(modelNames.contains("opencode-go/claude-sonnet-4"),
                           "Config must not contain prefixed model name in opencode-go block")
        }
    }

    /// Generated config does not contain /chat/completions, openai-compatibility,
    /// go.mod, or Go SDK package names.
    func testGeneratedConfigDoesNotContainChatCompletionsOrOpenAICompatibility() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "opencode-go", apiKey: "ocg-test-key",
                            authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertFalse(contents.contains("/chat/completions"),
                           "Config must not contain /chat/completions endpoint")
            XCTAssertFalse(contents.contains("openai-compatibility"),
                           "Config must not contain openai-compatibility")
            XCTAssertFalse(contents.contains("go.mod"),
                           "Config must not contain go.mod reference")
            XCTAssertFalse(contents.contains("opencode-sdk-go"),
                           "Config must not contain Go SDK package name")
        }
    }

    // MARK: - Catalog-Backed Config Model Names

    /// Z.AI config model names come from injected catalog data, not static Swift arrays.
    /// When catalogModelsOverride provides ZAI model names, those exact names appear in config.
    func testZAIConfigModelNamesComeFromCatalog() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.catalogModelsOverride = [
                "zai": ["catalog-glm-5.1", "catalog-glm-5"]
            ]

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let modelNames = modelNames(in: entry(withPrefix: "zai", in: entries))

            XCTAssertTrue(modelNames.contains("catalog-glm-5.1"),
                           "Config should contain catalog-derived ZAI model name")
            XCTAssertTrue(modelNames.contains("catalog-glm-5"),
                           "Config should contain catalog-derived ZAI model name")

            XCTAssertFalse(modelNames.contains("glm-5-turbo"),
                           "Config must not contain static fallback model name")
        }
    }

    /// MiniMax config model names come from injected catalog data, not static Swift arrays.
    func testMiniMaxConfigModelNamesComeFromCatalog() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "minimax", apiKey: "minimax-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.catalogModelsOverride = [
                "minimax": ["catalog-MiniMax-M3"]
            ]

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let modelNames = modelNames(in: entry(withPrefix: "minimax", in: entries))

            XCTAssertTrue(modelNames.contains("catalog-MiniMax-M3"),
                           "Config should contain catalog-derived MiniMax model name")

            XCTAssertFalse(modelNames.contains("MiniMax-M2.7"),
                           "Config must not contain static fallback MiniMax model name")
        }
    }

    func testKimiCredentialDoesNotGenerateClaudeAPIKeyConfig() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.catalogModelsOverride = [
                "kimi": ["catalog-kimi-k3"]
            ]

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)

            XCTAssertNil(entry(withPrefix: "kimi", in: entries),
                         "Kimi credentials should not generate claude-api-key config entries")
            XCTAssertFalse(entries.compactMap { $0["api-key"] as? String }.contains("kimi-test-key"),
                           "Generated config must not contain the Kimi API key")
        }
    }

    func testNoStaticModelFallbackWithoutCatalogOverride() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-test-key", authDir: authDir)
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let zaiModelNames = modelNames(in: entry(withPrefix: "zai", in: entries))
            let minimaxModelNames = modelNames(in: entry(withPrefix: "minimax", in: entries))

            XCTAssertTrue(zaiModelNames.contains("glm-5.1"),
                           "Config should contain catalog-derived ZAI model name glm-5.1")

            XCTAssertTrue(minimaxModelNames.contains("MiniMax-M2.7"),
                           "Config should contain catalog-derived MiniMax model name")
        }
    }

    // MARK: - Runtime Cache Observability Tests

    /// Writes a valid model-catalog-cache.json into the auth directory with the
    /// given provider model IDs and standard source metadata.
    /// Produces CatalogModelEntry-compatible JSON (id, object, created, ownedBy).
    private func writeRuntimeCacheFile(authDir: URL, providerModels: [String: [String]]) {
        var snapshotModels: [String: [[String: Any]]] = [:]
        for (provider, modelIDs) in providerModels {
            snapshotModels[provider] = modelIDs.map { id in
                [
                    "id": id,
                    "object": "model",
                    "created": 1_700_000_000,
                    "ownedBy": provider,
                    "displayName": id,
                    "tier": "free",
                    "supplementalMetadata": [String: String]()
                ] as [String: Any]
            }
        }
        let snapshot: [String: Any] = [
            "schemaVersion": "2",
            "generatedAt": "2026-06-05T00:00:00Z",
            "sources": ["models.json"],
            "providerModels": snapshotModels
        ]
        let data = try! JSONSerialization.data(withJSONObject: snapshot, options: .prettyPrinted)
        let cacheFile = authDir.appendingPathComponent("model-catalog-cache.json")
        try! data.write(to: cacheFile)
    }

    /// Generated config model names prefer model-catalog-cache.json over bundled snapshot
    /// when the runtime cache file contains valid data for a provider.
    func testConfigPrefersRuntimeCacheOverBundledSnapshot() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["runtime-exclusive-model"]
            ])

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let modelNames = modelNames(in: entry(withPrefix: "zai", in: entries))

            XCTAssertTrue(modelNames.contains("runtime-exclusive-model"),
                           "Config should use model names from runtime cache file")
        }
    }

    /// Subsequent config generation reflects runtime cache file updates after an
    /// initial config generation. This proves the memoization does not stale-lock
    /// the model list when the cache file changes on disk.
    func testSubsequentConfigGenerationReflectsCacheFileUpdate() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["cache-v1-model"]
            ])

            let manager = makeManager(authDir: authDir)

            let configPath1 = manager.getConfigPath()
            guard let contents1 = readConfig(at: configPath1) else { return }
            let entries1 = claudeAPIKeyEntries(from: contents1)
            let modelNames1 = modelNames(in: entry(withPrefix: "zai", in: entries1))
            XCTAssertTrue(modelNames1.contains("cache-v1-model"),
                          "First config should contain cache-v1-model")

            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["cache-v2-model"]
            ])

            let configPath2 = manager.getConfigPath()
            guard let contents2 = readConfig(at: configPath2) else { return }
            let entries2 = claudeAPIKeyEntries(from: contents2)
            let modelNames2 = modelNames(in: entry(withPrefix: "zai", in: entries2))
            XCTAssertTrue(modelNames2.contains("cache-v2-model"),
                          "Second config should reflect updated cache model")
            XCTAssertFalse(modelNames2.contains("cache-v1-model"),
                           "Second config should not contain stale v1 model")
        }
    }

    /// Invalid runtime cache (corrupt JSON) falls back to bundled snapshot data
    /// without errors. Config generation remains functional.
    func testInvalidRuntimeCacheFallsBackToBundledSnapshot() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            let corruptData = "not valid json".data(using: .utf8)!
            let cacheFile = authDir.appendingPathComponent("model-catalog-cache.json")
            try! corruptData.write(to: cacheFile)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)
            let modelNames = modelNames(in: entry(withPrefix: "zai", in: entries))

            XCTAssertTrue(modelNames.contains("glm-5.1"),
                           "Config should fall back to bundled snapshot when runtime cache is invalid")
        }
    }

    // MARK: - Config Exclusion Tests (Disabled / Empty-Key Credentials)

    /// Generated config must not emit a claude-api-key block for any API-key
    /// provider when the only credential is disabled.
    func testConfigExcludesProviderWhenCredentialDisabled() {
        let providers: [(String, String)] = [
            ("zai", "zai-key"),
            ("kimi", "kimi-key"),
            ("minimax", "minimax-key"),
            ("opencode-go", "ocg-key")
        ]

        for (provider, key) in providers {
            XCTContext.runActivity(named: "Disabled credential for \(provider)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: provider, apiKey: key,
                                    disabled: true, authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }
                    let entries = claudeAPIKeyEntries(from: contents)

                    XCTAssertFalse(entries.compactMap { $0["api-key"] as? String }.contains(key),
                                   "\(provider) config must not contain disabled credential key")
                    XCTAssertNil(entry(withPrefix: provider, in: entries),
                                   "\(provider) config must not emit block for disabled credential")
                }
            }
        }
    }

    /// Generated config must not emit a claude-api-key block for any API-key
    /// provider when the only credential has an empty API key.
    func testConfigExcludesProviderWhenEmptyApiKey() {
        let providers = ["zai", "kimi", "minimax", "opencode-go"]

        for provider in providers {
            XCTContext.runActivity(named: "Empty API key for \(provider)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: provider, apiKey: "", authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }
                    let entries = claudeAPIKeyEntries(from: contents)

                    XCTAssertNil(entry(withPrefix: provider, in: entries),
                                   "\(provider) config must not emit block for empty API key")
                }
            }
        }
    }

    /// Generated config must not emit a claude-api-key block for any API-key
    /// provider when the provider is disabled even if a valid credential exists.
    func testConfigExcludesProviderWhenProviderDisabled() {
        let providers: [(String, String)] = [
            ("zai", "zai-key"),
            ("kimi", "kimi-key"),
            ("minimax", "minimax-key"),
            ("opencode-go", "ocg-key")
        ]

        for (provider, key) in providers {
            XCTContext.runActivity(named: "Disabled provider \(provider)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredential(provider: provider, apiKey: key, authDir: authDir)

                    let manager = makeManager(authDir: authDir)
                    manager.enabledProviders[provider] = false

                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }
                    let entries = claudeAPIKeyEntries(from: contents)

                    XCTAssertFalse(entries.compactMap { $0["api-key"] as? String }.contains(key),
                                   "\(provider) config must not contain key when provider disabled")
                    XCTAssertNil(entry(withPrefix: provider, in: entries),
                                   "\(provider) config must not emit block when provider disabled")
                }
            }
        }
    }

    // MARK: - Type-Mismatch Tests (scanApiKeys type gate)

    /// A file named zai-*.json whose JSON type is "minimax" must be routed to
    /// the minimax provider block, not the zai block. JSON type is authoritative.
    func testConfigIgnoresMismatchedTypeForZAI() {
        withTemporaryAuthDirectory { authDir in
            writeMismatchedCredential(filenamePrefix: "zai", actualType: "minimax",
                                      apiKey: "minimax-key-in-zai-file", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)

            XCTAssertNil(entry(withPrefix: "zai", in: entries),
                           "Config must not emit zai block for mismatched type file")
        }
    }

    /// A file named kimi-*.json whose JSON type is "zai" must be routed to
    /// the zai provider block, not the kimi block. JSON type is authoritative.
    func testConfigIgnoresMismatchedTypeForKimi() {
        withTemporaryAuthDirectory { authDir in
            writeMismatchedCredential(filenamePrefix: "kimi", actualType: "zai",
                                      apiKey: "zai-key-in-kimi-file", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)

            XCTAssertNil(entry(withPrefix: "kimi", in: entries),
                           "Config must not emit kimi block for mismatched type file")
        }
    }

    /// A file named minimax-*.json whose JSON type is "zai" must be ignored
    /// for MiniMax connected-provider calculation.
    func testConnectedProviderIgnoresMismatchedTypeForMiniMax() {
        withTemporaryAuthDirectory { authDir in
            writeMismatchedCredential(filenamePrefix: "minimax", actualType: "zai",
                                      apiKey: "zai-key-in-minimax-file", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.minimax),
                           "minimax should be excluded when file has mismatched type")
        }
    }

    // MARK: - Unexpected Filename Tests (JSON type is authoritative)

    /// A credential file with an unexpected filename but correct JSON "type" field
    /// must still be recognized for config generation. JSON "type" is the
    /// authoritative provider identifier, not the filename prefix.
    func testConfigIncludesProviderWithValidTypeButUnexpectedFilename() {
        let providers = [
            "zai",
            "minimax",
            "opencode-go"
        ]

        for providerType in providers {
            XCTContext.runActivity(named: "Valid type with unexpected filename for \(providerType)") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredentialWithFilename(
                        filename: "backup-\(UUID().uuidString).json",
                        provider: providerType,
                        apiKey: "valid-key-unexpected-name",
                        authDir: authDir
                    )

                    let manager = makeManager(authDir: authDir)
                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }
                    let entries = claudeAPIKeyEntries(from: contents)
                    let providerEntry = entry(withPrefix: providerType, in: entries)

                    XCTAssertNotNil(providerEntry,
                                  "\(providerType) config must be emitted when JSON type is correct regardless of filename")
                    XCTAssertEqual(providerEntry?["api-key"] as? String, "valid-key-unexpected-name",
                                  "\(providerType) config must include the key from correctly-typed file with unexpected name")
                }
            }
        }
    }

    func testConfigDoesNotIncludeKimiWithValidTypeButUnexpectedFilename() {
        withTemporaryAuthDirectory { authDir in
            writeCredentialWithFilename(
                filename: "backup-\(UUID().uuidString).json",
                provider: "kimi",
                apiKey: "valid-kimi-key-unexpected-name",
                authDir: authDir
            )

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }
            let entries = claudeAPIKeyEntries(from: contents)

            XCTAssertNil(entry(withPrefix: "kimi", in: entries),
                         "Kimi should remain excluded from generated claude-api-key config regardless of credential filename")
            XCTAssertFalse(entries.compactMap { $0["api-key"] as? String }.contains("valid-kimi-key-unexpected-name"))
        }
    }

    /// A credential file with an unexpected filename but correct JSON "type" field
    /// must still be recognized for connected-provider calculation, matching
    /// connectedProviders() behavior.
    func testConnectedProviderIncludesProviderWithValidTypeButUnexpectedFilename() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("opencode-go", .opencodeGo)
        ]

        for (providerType, serviceType) in providers {
            XCTContext.runActivity(named: "Connected provider for \(providerType) with unexpected filename") { _ in
                withTemporaryAuthDirectory { authDir in
                    writeCredentialWithFilename(
                        filename: "migration-\(UUID().uuidString).json",
                        provider: providerType,
                        apiKey: "valid-key",
                        authDir: authDir
                    )

                    let manager = makeManager(authDir: authDir)
                    let connected = manager.connectedProviders(now: fixedNow)

                    XCTAssertTrue(connected.contains(serviceType),
                                  "\(providerType) should be connected when JSON type is correct regardless of filename")
                }
            }
        }
    }

    // MARK: - OAuth Expiration Field Tests

    /// OAuth credentials with expires_at before now are excluded.
    func testConnectedProviderExcludesOAuthWhenExpiresAtPast() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expires_at", value: "2020-01-01T00:00:00Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when expires_at is in the past")
        }
    }

    /// OAuth credentials with expires_at after now are included.
    func testConnectedProviderIncludesOAuthWhenExpiresAtFuture() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expires_at", value: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.claude),
                          "claude should be connected when expires_at is in the future")
        }
    }

    /// OAuth credentials with expiresAt before now are excluded.
    func testConnectedProviderExcludesOAuthWhenExpiresAtCamelCasePast() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expiresAt", value: "2020-01-01T00:00:00Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when expiresAt is in the past")
        }
    }

    /// OAuth credentials with expiresAt after now are included.
    func testConnectedProviderIncludesOAuthWhenExpiresAtCamelCaseFuture() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expiresAt", value: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.claude),
                          "claude should be connected when expiresAt is in the future")
        }
    }

    /// OAuth credentials with expiration before now are excluded.
    func testConnectedProviderExcludesOAuthWhenExpirationPast() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expiration", value: "2020-01-01T00:00:00Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when expiration is in the past")
        }
    }

    /// OAuth credentials with expiration after now are included.
    func testConnectedProviderIncludesOAuthWhenExpirationFuture() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expiration", value: "2099-12-31T23:59:59Z")

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.claude),
                          "claude should be connected when expiration is in the future")
        }
    }

    /// OAuth credentials with no expiration field remain non-expiring for
    /// backward compatibility.
    func testConnectedProviderIncludesOAuthWhenNoExpirationFields() {
        withTemporaryAuthDirectory { authDir in
            writeOAuthCredential(provider: "claude", authDir: authDir, expired: nil)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertTrue(connected.contains(.claude),
                          "claude should be connected when no expiration fields are present")
        }
    }

    /// OAuth credentials with expires_at exactly at now are treated as expired.
    func testConnectedProviderExcludesOAuthWhenExpiresAtEqualsNow() {
        withTemporaryAuthDirectory { authDir in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let expiresAtStr = formatter.string(from: fixedNow)

            writeOAuthCredentialWithExpiration(provider: "claude", authDir: authDir,
                                                field: "expires_at", value: expiresAtStr)

            let manager = makeManager(authDir: authDir)
            let connected = manager.connectedProviders(now: fixedNow)

            XCTAssertFalse(connected.contains(.claude),
                           "claude should be excluded when expires_at equals now")
        }
    }
}

extension ServerManagerConfigTests {
    private func makeManager(authDir: URL) -> ServerManager {
        let manager = ServerManager()
        manager.bundledConfigPathOverride = fixtureConfigPath
        manager.authDirectoryOverride = authDir
        return manager
    }

    private func withTemporaryAuthDirectory(_ body: (URL) -> Void) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-tests-\(UUID().uuidString)", isDirectory: true)
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

        writeCredentialFixture(file: file, credential: credential,
                               failureMessage: "Failed to write isolated auth fixture for \(provider)")
    }

    private func writeOAuthCredential(provider: String, authDir: URL,
                                       email: String = "test@test.com",
                                       disabled: Bool = false,
                                       accessToken: String? = nil,
                                       expired: String? = nil) {
        let file = authDir.appendingPathComponent("\(provider)-test-\(UUID().uuidString).json")
        var credential: [String: Any] = [
            "type": provider,
            "email": email,
            "login": email,
            "created": "2026-04-01T00:00:00Z"
        ]
        if disabled {
            credential["disabled"] = true
        }
        if let accessToken {
            credential["access_token"] = accessToken
        }
        if let expired {
            credential["expired"] = expired
        }

        writeCredentialFixture(file: file, credential: credential,
                               failureMessage: "Failed to write OAuth credential for \(provider)")
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
        writeCredentialFixture(file: file, credential: credential,
                               failureMessage: "Failed to write mismatched credential")
    }

    private func writeCredentialWithFilename(filename: String, provider: String,
                                              apiKey: String, authDir: URL) {
        let file = authDir.appendingPathComponent(filename)
        let credential: [String: Any] = [
            "type": provider,
            "email": "test",
            "api_key": apiKey,
            "created": "2026-04-01T00:00:00Z"
        ]
        writeCredentialFixture(file: file, credential: credential,
                               failureMessage: "Failed to write credential with custom filename")
    }

    private func writeOAuthCredentialWithExpiration(provider: String, authDir: URL,
                                                     field: String, value: String) {
        let file = authDir.appendingPathComponent("\(provider)-test-\(UUID().uuidString).json")
        var credential: [String: Any] = [
            "type": provider,
            "email": "test@test.com",
            "login": "test@test.com",
            "created": "2026-04-01T00:00:00Z"
        ]
        credential[field] = value

        writeCredentialFixture(file: file, credential: credential,
                               failureMessage: "Failed to write OAuth credential with \(field) for \(provider)")
    }

    private func writeCredentialFixture(file: URL, credential: [String: Any], failureMessage: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("\(failureMessage): \(error)")
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

    private func parseConfig(_ contents: String) -> [String: Any] {
        do {
            guard let document = try Yams.load(yaml: contents) as? [String: Any] else {
                XCTFail("Generated config should parse as a YAML mapping")
                return [:]
            }
            return document
        } catch {
            XCTFail("Generated config should be valid YAML: \(error)")
            return [:]
        }
    }

    private func claudeAPIKeyEntries(from contents: String) -> [[String: Any]] {
        parseConfig(contents)["claude-api-key"] as? [[String: Any]] ?? []
    }

    private func entry(withPrefix prefix: String, in entries: [[String: Any]]) -> [String: Any]? {
        entries.first { $0["prefix"] as? String == prefix }
    }

    private func modelNames(in entry: [String: Any]?) -> [String] {
        guard let models = entry?["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    private func oauthExcludedModels(from contents: String) -> [String: Any] {
        parseConfig(contents)["oauth-excluded-models"] as? [String: Any] ?? [:]
    }

    private func restoreUserDefault(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
