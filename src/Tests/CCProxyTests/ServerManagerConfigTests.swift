import XCTest
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

            XCTAssertTrue(contents.contains("secret-key: \"test-secret\""))
        }
    }

    func testMergedConfigAddsClaudeCompatibleUpstreamsForSupportedProviders() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertTrue(contents.contains("claude-api-key:"))
            XCTAssertTrue(contents.contains("api-key: \"zai-test-key\""))
            XCTAssertTrue(contents.contains("api-key: \"kimi-test-key\""))
            XCTAssertTrue(contents.contains("api-key: \"minimax-test-key\""))
            XCTAssertTrue(contents.contains("prefix: \"zai\"\n    base-url: \"https://api.z.ai/api/anthropic\""))
            XCTAssertTrue(contents.contains("prefix: \"kimi\"\n    base-url: \"https://api.kimi.com/coding/\""))
            XCTAssertTrue(contents.contains("prefix: \"minimax\"\n    base-url: \"https://api.minimax.io/anthropic\""))
            XCTAssertFalse(contents.contains("alias:"))
        }
    }

    /// Generated config must not contain the obsolete timeout key removed from bundled config.
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

    /// Generated config must include exactly one top-level `force-model-prefix: true` key
    /// so prefixed provider models are exposed only through their provider-prefixed IDs.
    func testGeneratedConfigIncludesForceModelPrefix() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            let lines = contents.components(separatedBy: "\n")
            let topLevelForceModelPrefix = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed == "force-model-prefix: true"
                    && !line.hasPrefix(" ")
                    && !line.hasPrefix("\t")
            }

            XCTAssertEqual(topLevelForceModelPrefix.count, 1,
                           "Generated config must contain exactly one top-level force-model-prefix: true line, found \(topLevelForceModelPrefix.count)")
        }
    }

    func testOAuthDisabledProvidersGenerateExclusions() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "oauth-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.enabledProviders["claude"] = false
            manager.enabledProviders["codex"] = false

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertTrue(contents.contains("oauth-excluded-models:"),
                          "Config should contain oauth-excluded-models section")
            XCTAssertTrue(contents.contains("  claude:\n    - \"*\""),
                          "Disabled 'claude' provider should have wildcard exclusion")
            XCTAssertTrue(contents.contains("  codex:\n    - \"*\""),
                          "Disabled 'codex' provider should have wildcard exclusion")

            // Verify removed provider OAuth keys are absent
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

    /// Verifies oauthProviderKeys contains only Claude and Codex.
    func testOAuthProviderKeysOnlyContainClaudeAndCodex() {
        XCTAssertEqual(ServerManager.oauthProviderKeys, ["claude": "claude", "codex": "codex"])
    }

    /// Verifies the bundled config.yaml does not contain retired entries.
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

        // Build removed config-key needle from fragments
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

    /// Verifies active source and test files do not contain removed provider names.
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

    /// Validation path: no existing YAML parser dependency is available in this package.
    /// This uses an independent narrow double-quoted scalar decoder, not production encoding.
    /// Residual risk: this helper is not a general YAML parser.
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

                    XCTAssertTrue(extractAllApiKeyValues(from: contents).contains(testCase.apiKey),
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

    /// With enabled claude or codex but no provider-matching OAuth auth file/account,
    /// the connected-provider set excludes that provider.
    func testConnectedProviderExcludesOAuthWhenNoAuthFile() {
        withTemporaryAuthDirectory { authDir in
            // No auth files at all

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
            // Expired before fixedNow
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: "2020-01-01T00:00:00Z")
            // Expired before fixedNow (using a date 1 minute before fixedNow)
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 expired: "2026-05-31T23:59:00Z")

            let manager = makeManager(authDir: authDir)
            // fixedNow is 2026-06-01T00:00:00Z, both expired dates are before it
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
            // Create a credential whose expiration matches the injected now exactly
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

    /// With enabled zai, minimax, kimi, or opencode-go and at least one matching
    /// non-disabled API-key credential file/account with a non-empty key,
    /// the connected-provider set contains that provider.
    func testConnectedProviderIncludesAPIKeyProviderWithValidKey() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("kimi", .kimi),
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

    /// With enabled zai, minimax, kimi, or opencode-go but no matching API-key
    /// credential, the connected-provider set excludes that provider.
    func testConnectedProviderExcludesAPIKeyProviderWithNoMatchingKey() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("kimi", .kimi),
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
            ("kimi", .kimi),
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
            ("kimi", .kimi),
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
    /// or opencode-go, the connected-provider set excludes that provider even
    /// when valid auth or API-key credentials exist.
    func testConnectedProviderExcludesDisabledProviderEvenWithValidCredentials() {
        withTemporaryAuthDirectory { authDir in
            // Write valid credentials for all providers
            writeOAuthCredential(provider: "claude", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")
            writeOAuthCredential(provider: "codex", authDir: authDir,
                                 expired: "2099-12-31T23:59:59Z")
            writeCredential(provider: "zai", apiKey: "zai-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-key", authDir: authDir)
            writeCredential(provider: "kimi", apiKey: "kimi-key", authDir: authDir)
            writeCredential(provider: "opencode-go", apiKey: "ocg-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            // Disable all providers
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
            // Enabled but no credential files at all
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

            XCTAssertTrue(contents.contains("api-key: \"opencode-test-key\""),
                          "Config should contain the OpenCode Go API key")
            XCTAssertTrue(contents.contains("prefix: \"opencode-go\""),
                          "Config should contain opencode-go prefix")
            XCTAssertTrue(contents.contains("base-url: \"https://opencode.ai/zen/go/v1/messages\""),
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

            // Config must contain unprefixed model slugs
            XCTAssertTrue(contents.contains("- name: \"kimi-k2.6\""),
                          "Config should contain unprefixed slug kimi-k2.6")
            XCTAssertTrue(contents.contains("- name: \"claude-sonnet-4\""),
                          "Config should contain unprefixed slug claude-sonnet-4")

            // Config must NOT double-prefix
            XCTAssertFalse(contents.contains("opencode-go/opencode-go/"),
                           "Config must not contain double-prefixed model names")
            XCTAssertFalse(contents.contains("- name: \"opencode-go/kimi-k2.6\""),
                           "Config must not contain prefixed model name in opencode-go block")
            XCTAssertFalse(contents.contains("- name: \"opencode-go/claude-sonnet-4\""),
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

    // MARK: - Task 5: Catalog-Backed Config Model Names

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

            // Config must contain the catalog-derived model names
            XCTAssertTrue(contents.contains("- name: \"catalog-glm-5.1\""),
                           "Config should contain catalog-derived ZAI model name")
            XCTAssertTrue(contents.contains("- name: \"catalog-glm-5\""),
                           "Config should contain catalog-derived ZAI model name")

            // Must NOT contain static fallback names
            XCTAssertFalse(contents.contains("- name: \"glm-5-turbo\""),
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

            XCTAssertTrue(contents.contains("- name: \"catalog-MiniMax-M3\""),
                           "Config should contain catalog-derived MiniMax model name")

            // Must NOT contain static fallback name
            XCTAssertFalse(contents.contains("- name: \"MiniMax-M2.7\""),
                           "Config must not contain static fallback MiniMax model name")
        }
    }

    /// Kimi config model names come from injected catalog data, not static Swift arrays.
    func testKimiConfigModelNamesComeFromCatalog() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            manager.catalogModelsOverride = [
                "kimi": ["catalog-kimi-k3"]
            ]

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertTrue(contents.contains("- name: \"catalog-kimi-k3\""),
                           "Config should contain catalog-derived Kimi model name")

            // Must NOT contain static fallback name
            XCTAssertFalse(contents.contains("- name: \"kimi-k2-turbo-preview\""),
                           "Config must not contain static fallback Kimi model name")
        }
    }

    /// When no catalogModelsOverride is provided, config model names come from the
    /// bundled catalog snapshot rather than hardcoded Swift arrays. This proves the
    /// runtime config path derives model lists from the external catalog.
    /// The bundled snapshot has more models than the old static arrays ever did,
    /// so we verify that the config contains catalog-specific model names that were
    /// never in the static arrays.
    func testNoStaticModelFallbackWithoutCatalogOverride() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)
            writeCredential(provider: "minimax", apiKey: "minimax-test-key", authDir: authDir)
            writeCredential(provider: "kimi", apiKey: "kimi-test-key", authDir: authDir)

            let manager = makeManager(authDir: authDir)
            // Explicitly do NOT set catalogModelsOverride
            // The config should use bundled snapshot models, not hardcoded arrays

            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            // The bundled snapshot contains ZAI models beyond the old static list.
            // Verify that models NOT in the old static list appear in config,
            // proving the source is the catalog, not the hardcoded arrays.
            // Old static ZAI list was: glm-5.1, glm-5, glm-5-turbo, glm-5v-turbo,
            //   glm-4.7, glm-4.7-flash, glm-4.6v, glm-4.5-air
            // The external catalog also has glm-4.5-air but we verify it includes
            // catalog-derived models by checking the config has model name entries.

            // The config must have model names from the bundled snapshot for each provider.
            // Verify that the ZAI block contains at least the basic model "glm-5.1"
            XCTAssertTrue(contents.contains("- name: \"glm-5.1\""),
                           "Config should contain catalog-derived ZAI model name glm-5.1")

            // Verify Kimi has catalog models (bundled snapshot has multiple kimi models)
            // Old static list only had "kimi-k2-turbo-preview"; catalog has more.
            // Verify that kimi-k2.6 (a catalog-specific model) appears.
            XCTAssertTrue(contents.contains("- name: \"kimi-k2.6\""),
                           "Config should contain catalog-derived Kimi model name kimi-k2.6")

            // Verify the old static MiniMax list only had "MiniMax-M2.7".
            // The catalog should still provide it (or more).
            XCTAssertTrue(contents.contains("- name: \"MiniMax-M2.7\""),
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

            // Write a runtime cache with a unique model name not in the bundled snapshot
            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["runtime-exclusive-model"]
            ])

            let manager = makeManager(authDir: authDir)
            // Explicitly do NOT set catalogModelsOverride — should read from runtime cache
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            XCTAssertTrue(contents.contains("- name: \"runtime-exclusive-model\""),
                           "Config should use model names from runtime cache file")
        }
    }

    /// Subsequent config generation reflects runtime cache file updates after an
    /// initial config generation. This proves the memoization does not stale-lock
    /// the model list when the cache file changes on disk.
    func testSubsequentConfigGenerationReflectsCacheFileUpdate() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            // Write initial runtime cache
            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["cache-v1-model"]
            ])

            let manager = makeManager(authDir: authDir)

            // First config generation — should use initial cache
            let configPath1 = manager.getConfigPath()
            guard let contents1 = readConfig(at: configPath1) else { return }
            XCTAssertTrue(contents1.contains("- name: \"cache-v1-model\""),
                          "First config should contain cache-v1-model")

            // Update the runtime cache file with a different model
            writeRuntimeCacheFile(authDir: authDir, providerModels: [
                "zai": ["cache-v2-model"]
            ])

            // Second config generation — should reflect the updated cache
            let configPath2 = manager.getConfigPath()
            guard let contents2 = readConfig(at: configPath2) else { return }
            XCTAssertTrue(contents2.contains("- name: \"cache-v2-model\""),
                          "Second config should reflect updated cache model")
            XCTAssertFalse(contents2.contains("- name: \"cache-v1-model\""),
                           "Second config should not contain stale v1 model")
        }
    }

    /// Invalid runtime cache (corrupt JSON) falls back to bundled snapshot data
    /// without errors. Config generation remains functional.
    func testInvalidRuntimeCacheFallsBackToBundledSnapshot() {
        withTemporaryAuthDirectory { authDir in
            writeCredential(provider: "zai", apiKey: "zai-test-key", authDir: authDir)

            // Write invalid (corrupt) runtime cache
            let corruptData = "not valid json".data(using: .utf8)!
            let cacheFile = authDir.appendingPathComponent("model-catalog-cache.json")
            try! corruptData.write(to: cacheFile)

            let manager = makeManager(authDir: authDir)
            let configPath = manager.getConfigPath()

            guard let contents = readConfig(at: configPath) else { return }

            // Should fall back to bundled snapshot — which contains glm-5.1
            XCTAssertTrue(contents.contains("- name: \"glm-5.1\""),
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

                    XCTAssertFalse(contents.contains("api-key: \"\(key)\""),
                                   "\(provider) config must not contain disabled credential key")
                    XCTAssertFalse(contents.contains("prefix: \"\(provider)\""),
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

                    XCTAssertFalse(contents.contains("prefix: \"\(provider)\""),
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

                    XCTAssertFalse(contents.contains("api-key: \"\(key)\""),
                                   "\(provider) config must not contain key when provider disabled")
                    XCTAssertFalse(contents.contains("prefix: \"\(provider)\""),
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

            // The key should NOT appear under the zai prefix (wrong provider)
            // but MAY appear under the minimax prefix (correct JSON type)
            XCTAssertFalse(contents.contains("prefix: \"zai\""),
                           "Config must not emit zai block for mismatched type file")
            XCTAssertFalse(contents.contains("prefix: \"zai\"\n    base-url: \"https://api.z.ai/api/anthropic\""),
                           "Config must not emit zai block when the only credential has minimax type")
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

            // The key should NOT appear under the kimi prefix (wrong provider)
            // but MAY appear under the zai prefix (correct JSON type)
            XCTAssertFalse(contents.contains("prefix: \"kimi\""),
                           "Config must not emit kimi block for mismatched type file")
            XCTAssertFalse(contents.contains("prefix: \"kimi\"\n    base-url: \"https://api.kimi.com/coding/\""),
                           "Config must not emit kimi block when the only credential has zai type")
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
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("kimi", .kimi),
            ("opencode-go", .opencodeGo)
        ]

        for (providerType, serviceType) in providers {
            XCTContext.runActivity(named: "Valid type with unexpected filename for \(providerType)") { _ in
                withTemporaryAuthDirectory { authDir in
                    // Write a credential with an unexpected filename (e.g. "backup-xxx.json")
                    // but correct JSON "type" field
                    writeCredentialWithFilename(
                        filename: "backup-\(UUID().uuidString).json",
                        provider: providerType,
                        apiKey: "valid-key-unexpected-name",
                        authDir: authDir
                    )

                    let manager = makeManager(authDir: authDir)
                    let configPath = manager.getConfigPath()

                    guard let contents = readConfig(at: configPath) else { return }

                    XCTAssertTrue(contents.contains("prefix: \"\(providerType)\""),
                                  "\(providerType) config must be emitted when JSON type is correct regardless of filename")
                    XCTAssertTrue(contents.contains("api-key: \"valid-key-unexpected-name\""),
                                  "\(providerType) config must include the key from correctly-typed file with unexpected name")
                }
            }
        }
    }

    /// A credential file with an unexpected filename but correct JSON "type" field
    /// must still be recognized for connected-provider calculation, matching
    /// connectedProviders() behavior.
    func testConnectedProviderIncludesProviderWithValidTypeButUnexpectedFilename() {
        let providers: [(String, ServiceType)] = [
            ("zai", .zai),
            ("minimax", .minimax),
            ("kimi", .kimi),
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
            // Write an OAuth credential with no expired/expires_at/expiresAt/expiration
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
    private func makeManager(authDir: URL, bundledConfigPath: String? = nil) -> ServerManager {
        let manager = ServerManager()
        manager.bundledConfigPathOverride = bundledConfigPath ?? fixtureConfigPath
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

    private func writeTemporaryConfig(contents: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-config-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let configURL = root.appendingPathComponent("config.yaml")
            try contents.write(to: configURL, atomically: true, encoding: .utf8)
            addTeardownBlock { try? FileManager.default.removeItem(at: root) }
            return configURL
        } catch {
            XCTFail("Failed to create temporary config fixture: \(error)")
            return URL(fileURLWithPath: fixtureConfigPath)
        }
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
            XCTFail("Failed to write isolated auth fixture for \(provider): \(error)")
        }
    }

    private func writeOAuthCredential(provider: String, authDir: URL,
                                       email: String = "test@test.com",
                                       disabled: Bool = false, expired: String? = nil) {
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
        if let expired {
            credential["expired"] = expired
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("Failed to write OAuth credential for \(provider): \(error)")
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

    private func writeCredentialWithFilename(filename: String, provider: String,
                                              apiKey: String, authDir: URL) {
        let file = authDir.appendingPathComponent(filename)
        let credential: [String: Any] = [
            "type": provider,
            "email": "test",
            "api_key": apiKey,
            "created": "2026-04-01T00:00:00Z"
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("Failed to write credential with custom filename: \(error)")
        }
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

        do {
            let data = try JSONSerialization.data(withJSONObject: credential, options: .prettyPrinted)
            try data.write(to: file)
        } catch {
            XCTFail("Failed to write OAuth credential with \(field) for \(provider): \(error)")
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

    private func restoreUserDefault(_ value: Any?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func decodeYamlDoubleQuotedScalar(_ scalar: String) -> String {
        guard scalar.hasPrefix("\"") && scalar.hasSuffix("\"") && scalar.count >= 2 else {
            return scalar
        }
        let start = scalar.index(after: scalar.startIndex)
        let end = scalar.index(before: scalar.endIndex)
        let content = scalar[start..<end]

        var result = ""
        var i = content.startIndex

        while i < content.endIndex {
            let char = content[i]
            if char == "\\" {
                let next = content.index(after: i)
                guard next < content.endIndex else {
                    result.append("\\")
                    break
                }
                let nextChar = content[next]
                switch nextChar {
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "0": result.append("\0")
                case "a": result.append("\u{07}")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "v": result.append("\u{0B}")
                case " ": result.append(" ")
                default: result.append(nextChar)
                }
                i = content.index(after: next)
            } else {
                result.append(char)
                i = content.index(after: i)
            }
        }

        return result
    }

    private func extractAllApiKeyValues(from configContent: String) -> [String] {
        var results: [String] = []
        let lines = configContent.components(separatedBy: "\n")

        for line in lines {
            guard let prefixRange = line.range(of: "- api-key: \"") else { continue }
            let afterOpeningQuote = prefixRange.upperBound

            var pos = afterOpeningQuote
            var rawContent = ""
            while pos < line.endIndex {
                let char = line[pos]
                if char == "\\" {
                    rawContent.append(char)
                    let next = line.index(after: pos)
                    if next < line.endIndex {
                        rawContent.append(line[next])
                        pos = line.index(after: next)
                    } else {
                        pos = line.index(after: pos)
                    }
                } else if char == "\"" {
                    break
                } else {
                    rawContent.append(char)
                    pos = line.index(after: pos)
                }
            }

            results.append(decodeYamlDoubleQuotedScalar("\"" + rawContent + "\""))
        }

        return results
    }
}
