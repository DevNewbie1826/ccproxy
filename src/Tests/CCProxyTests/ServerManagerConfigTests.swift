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
            XCTAssertTrue(contents.contains("- name: \"glm-5.1\""))
            XCTAssertTrue(contents.contains("- name: \"glm-5\""))
            XCTAssertTrue(contents.contains("- name: \"glm-5-turbo\""))
            XCTAssertTrue(contents.contains("- name: \"glm-5v-turbo\""))
            XCTAssertTrue(contents.contains("- name: \"glm-4.7\""))
            XCTAssertTrue(contents.contains("- name: \"glm-4.7-flash\""))
            XCTAssertTrue(contents.contains("- name: \"glm-4.6v\""))
            XCTAssertTrue(contents.contains("- name: \"glm-4.5-air\""))
            XCTAssertTrue(contents.contains("prefix: \"kimi\"\n    base-url: \"https://api.kimi.com/coding/\""))
            XCTAssertTrue(contents.contains("- name: \"kimi-k2-turbo-preview\""))
            XCTAssertTrue(contents.contains("prefix: \"minimax\"\n    base-url: \"https://api.minimax.io/anthropic\""))
            XCTAssertTrue(contents.contains("- name: \"MiniMax-M2.7\""))
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

    private func writeCredential(provider: String, apiKey: String, authDir: URL) {
        let file = authDir.appendingPathComponent("\(provider)-test-\(UUID().uuidString).json")
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
            XCTFail("Failed to write isolated auth fixture for \(provider): \(error)")
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
