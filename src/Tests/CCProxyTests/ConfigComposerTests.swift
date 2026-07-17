import XCTest
import Yams
@testable import CCProxy

final class ConfigComposerTests: XCTestCase {
    private var bundledConfigPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Resources/config.yaml")
            .path
    }

    private var bundledYAML: String {
        get throws {
            try String(contentsOfFile: bundledConfigPath, encoding: .utf8)
        }
    }

    func testCompose_ReplacesManagementSecretWithEscapedValue() throws {
        let merged = try compose(managementSecretKey: "abc\"\\def\n")
        let document = try parseMapping(merged)
        let remoteManagement = try XCTUnwrap(document["remote-management"] as? [String: Any])

        XCTAssertEqual(remoteManagement["secret-key"] as? String, "abc\"\\def\n",
                       "ConfigComposer should YAML-escape and inject the exact management secret")
    }

    func testCompose_WithNoInputsPreservesBundledConfig() throws {
        let bundled = try bundledYAML
        let merged = try compose(bundledYAML: bundled)
        let document = try parseMapping(merged)

        XCTAssertEqual(document["port"] as? Int, 8328)
        XCTAssertEqual(document["host"] as? String, "127.0.0.1")
        XCTAssertEqual(document["force-model-prefix"] as? Bool, true)
        XCTAssertTrue(yamlMappingsEqual(try parseMapping(bundled), document),
                      "No-op composition should parse equal to bundled config")
    }

    func testCompose_InjectsClaudeAPIKeyEntriesForEachKeyWithoutAliases() throws {
        let merged = try compose(upstreams: [zaiUpstream(apiKeys: ["k1", "k2"])])
        let entries = try claudeAPIKeyEntries(from: merged)

        XCTAssertEqual(entries.count, 2, "ConfigComposer should emit one claude-api-key entry per API key")
        XCTAssertEqual(entries.map { $0["api-key"] as? String }, ["k1", "k2"])
        for entry in entries {
            XCTAssertEqual(entry["prefix"] as? String, "zai")
            XCTAssertEqual(entry["base-url"] as? String, "https://api.z.ai/api/anthropic")
            XCTAssertEqual(modelNames(in: entry), ["glm-5.1", "glm-5"],
                           "Injected model order should match the upstream model order")
            XCTAssertNil(entry["alias"], "Injected model entries should omit alias and let the server default alias=name")
        }
    }

    func testCompose_DeduplicatesAPIKeysByKeyAndBaseURLPreservingOrder() throws {
        let merged = try compose(upstreams: [zaiUpstream(apiKeys: ["k1", "k1", "k2"])])
        let entries = try claudeAPIKeyEntries(from: merged)

        XCTAssertEqual(entries.map { $0["api-key"] as? String }, ["k1", "k2"],
                       "ConfigComposer should deduplicate identical api-key/base-url pairs while preserving first-seen order")
    }

    func testCompose_EmitsExcludedModelsOnlyWhenNonEmpty() throws {
        let mergedWithExclusions = try compose(upstreams: [zaiUpstream(apiKeys: ["k1"], excludedModels: ["glm-4-*"])])
        let excludedEntry = try XCTUnwrap(claudeAPIKeyEntries(from: mergedWithExclusions).first)
        XCTAssertEqual(excludedEntry["excluded-models"] as? [String], ["glm-4-*"],
                       "ConfigComposer should copy non-empty excludedModels to each injected entry")

        let mergedWithoutExclusions = try compose(upstreams: [zaiUpstream(apiKeys: ["k1"], excludedModels: [])])
        let plainEntry = try XCTUnwrap(claudeAPIKeyEntries(from: mergedWithoutExclusions).first)
        XCTAssertNil(plainEntry["excluded-models"],
                     "ConfigComposer should omit excluded-models when the upstream has no exclusions")
    }

    func testCompose_AddsOAuthExcludedModelsForDisabledProvidersSorted() throws {
        let merged = try compose(disabledOAuthProviders: ["codex", "claude"])
        let document = try parseMapping(merged)
        let exclusions = try XCTUnwrap(document["oauth-excluded-models"] as? [String: Any])

        XCTAssertEqual(Array(exclusions.keys).sorted(), ["claude", "codex"])
        XCTAssertEqual(exclusions["claude"] as? [String], ["*"])
        XCTAssertEqual(exclusions["codex"] as? [String], ["*"])
    }

    func testCompose_UpsertsDisabledOAuthProvidersIntoBundledExclusions() throws {
        let bundled = try bundledYAML + """

        oauth-excluded-models:
          codex:
            - gpt-old-*
        """
        let merged = try compose(
            bundledYAML: bundled,
            disabledOAuthProviders: ["claude"]
        )
        let exclusions = try oauthExcludedModels(from: merged)

        XCTAssertEqual(exclusions["codex"] as? [String], ["gpt-old-*"])
        XCTAssertEqual(exclusions["claude"] as? [String], ["*"])
    }

    func testCompose_DisabledOAuthProviderWinsOverOverlayExclusion() throws {
        let overlay = """
        oauth-excluded-models:
          claude:
            - claude-3-*
        """
        let merged = try compose(
            userOverlayYAML: overlay,
            disabledOAuthProviders: ["claude"]
        )
        let exclusions = try oauthExcludedModels(from: merged)

        XCTAssertEqual(exclusions["claude"] as? [String], ["*"],
                       "Disabled provider generation should override any narrower user exclusion")
    }

    func testCompose_MergesOverlayScalarAdditivelyAndOverridesBundledScalar() throws {
        let overlay = """
        debug: true
        request-retry: 5
        """
        let merged = try compose(userOverlayYAML: overlay)
        let document = try parseMapping(merged)

        XCTAssertEqual(document["debug"] as? Bool, true, "Overlay should add/override scalar debug")
        XCTAssertEqual(document["request-retry"] as? Int, 5, "Overlay request-retry should override bundled value 3")
    }

    func testCompose_MergesOverlayClaudeAPIKeyEntriesBeforeInjectedEntries() throws {
        let overlay = """
        claude-api-key:
          - name: mine
            base-url: https://x
            api-key: u
            models:
              - name: m1
        """
        let merged = try compose(userOverlayYAML: overlay, upstreams: [zaiUpstream(apiKeys: ["k1"])])
        let entries = try claudeAPIKeyEntries(from: merged)

        XCTAssertEqual(entries.count, 2, "Overlay claude-api-key entries and injected entries should coexist")
        XCTAssertEqual(entries.first?["name"] as? String, "mine", "Overlay entry should remain first and preserve name")
        XCTAssertEqual(entries.first?["api-key"] as? String, "u")
        XCTAssertNil(entries.last?["name"], "Injected entries should not synthesize a name")
        XCTAssertEqual(entries.last?["api-key"] as? String, "k1")
    }

    func testCompose_MergesUnknownNamedArraysByNameWithOverlayWinning() throws {
        let bundled = try bundledYAML + """

        openai-compatibility:
          - name: shared
            base-url: https://old
          - name: existing
            base-url: https://existing
        """
        let overlay = """
        openai-compatibility:
          - name: shared
            base-url: https://new
          - name: added
            base-url: https://added
        """
        let merged = try compose(
            bundledYAML: bundled,
            userOverlayYAML: overlay
        )
        let document = try parseMapping(merged)
        let entries = try XCTUnwrap(document["openai-compatibility"] as? [[String: Any]])

        XCTAssertEqual(entries.map { $0["name"] as? String }, ["shared", "existing", "added"],
                       "Named arrays should merge by name and append new overlay names")
        XCTAssertEqual(entries.first?["base-url"] as? String, "https://new",
                       "Same-name overlay entry should override the bundled entry")
    }

    func testWriteMergedConfig_WritesMergedConfigWithOwnerOnlyPermissions() throws {
        try withTemporaryAuthDirectory { authDir in
            let returnedPath = try writeMergedConfig(
                authDir: authDir,
                userConfigPath: nil,
                upstreams: [zaiUpstream(apiKeys: ["k1"])]
            )
            let expectedPath = authDir.appendingPathComponent("merged-config.yaml").path
            let attributes = try FileManager.default.attributesOfItem(atPath: returnedPath)

            XCTAssertEqual(returnedPath, expectedPath, "ConfigComposer should return the generated merged-config.yaml path")
            XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600,
                           "merged-config.yaml should be written with owner read/write permissions only")
        }
    }

    func testWriteMergedConfig_WithNoInputsAndNoOverlayUsesBundledFastPath() throws {
        try withTemporaryAuthDirectory { authDir in
            let returnedPath = try writeMergedConfig(authDir: authDir, userConfigPath: nil)
            let mergedPath = authDir.appendingPathComponent("merged-config.yaml")

            XCTAssertEqual(returnedPath, bundledConfigPath,
                           "Fast path should return bundledConfigPath when there is nothing to merge")
            XCTAssertFalse(FileManager.default.fileExists(atPath: mergedPath.path),
                           "Fast path should not create merged-config.yaml")
            XCTAssertTrue(yamlMappingsEqual(try parseMapping(String(contentsOfFile: returnedPath, encoding: .utf8)),
                                            try parseMapping(bundledYAML)),
                          "Returned bundled config should parse equal to the bundled YAML")
        }
    }

    func testWriteMergedConfig_ReadsAndAppliesOverlayFile() throws {
        try withTemporaryAuthDirectory { authDir in
            let overlayURL = authDir.appendingPathComponent("overlay.yaml")
            try "request-retry: 5\n".write(to: overlayURL, atomically: true, encoding: .utf8)

            let returnedPath = try writeMergedConfig(authDir: authDir, userConfigPath: overlayURL)
            let contents = try String(contentsOfFile: returnedPath, encoding: .utf8)
            let document = try parseMapping(contents)

            XCTAssertEqual(document["request-retry"] as? Int, 5,
                           "writeMergedConfig should read and apply the user overlay file")
        }
    }

    func testWriteMergedConfig_ThrowsForMalformedOverlayFile() throws {
        try withTemporaryAuthDirectory { authDir in
            let overlayURL = authDir.appendingPathComponent("bad-overlay.yaml")
            try "debug: [unterminated\n".write(to: overlayURL, atomically: true, encoding: .utf8)

            XCTAssertThrowsError(try writeMergedConfig(
                authDir: authDir,
                userConfigPath: overlayURL
            ), "Malformed overlay YAML should throw instead of silently falling back")
        }
    }

    func testWriteMergedConfig_TreatsEmptyOverlayFileAsNoOverlay() throws {
        try assertEmptyOverlayFileIsNoOp("")
    }

    func testWriteMergedConfig_TreatsWhitespaceOnlyOverlayFileAsNoOverlay() throws {
        try assertEmptyOverlayFileIsNoOp(" \n\t  \n")
    }

    func testWriteMergedConfig_TreatsCommentOnlyOverlayFileAsNoOverlay() throws {
        try assertEmptyOverlayFileIsNoOp("# hello\n")
    }
}

private extension ConfigComposerTests {
    func compose(
        bundledYAML: String? = nil,
        userOverlayYAML: String? = nil,
        upstreams: [ClaudeCompatibleUpstream] = [],
        disabledOAuthProviders: [String] = [],
        managementSecretKey: String = ""
    ) throws -> String {
        try ConfigComposer.compose(
            bundledYAML: bundledYAML ?? self.bundledYAML,
            userOverlayYAML: userOverlayYAML,
            upstreams: upstreams,
            disabledOAuthProviders: disabledOAuthProviders,
            managementSecretKey: managementSecretKey
        )
    }

    func writeMergedConfig(
        authDir: URL,
        userConfigPath: URL?,
        upstreams: [ClaudeCompatibleUpstream] = [],
        disabledOAuthProviders: [String] = [],
        managementSecretKey: String = ""
    ) throws -> String {
        try ConfigComposer.writeMergedConfig(
            bundledConfigPath: bundledConfigPath,
            authDir: authDir,
            userConfigPath: userConfigPath,
            upstreams: upstreams,
            disabledOAuthProviders: disabledOAuthProviders,
            managementSecretKey: managementSecretKey
        )
    }

    func zaiUpstream(apiKeys: [String], excludedModels: [String] = []) -> ClaudeCompatibleUpstream {
        ClaudeCompatibleUpstream(
            prefix: "zai",
            baseURL: "https://api.z.ai/api/anthropic",
            apiKeys: apiKeys,
            models: ["glm-5.1", "glm-5"],
            excludedModels: excludedModels
        )
    }

    func withTemporaryAuthDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-config-composer-\(UUID().uuidString)", isDirectory: true)
        let authDir = root.appendingPathComponent("auth", isDirectory: true)
        try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(authDir)
    }

    func parseMapping(_ yaml: String) throws -> [String: Any] {
        try XCTUnwrap(Yams.load(yaml: yaml) as? [String: Any], "YAML document should parse as a mapping")
    }

    func claudeAPIKeyEntries(from yaml: String) throws -> [[String: Any]] {
        let document = try parseMapping(yaml)
        return try XCTUnwrap(document["claude-api-key"] as? [[String: Any]],
                             "ConfigComposer should emit a top-level claude-api-key array")
    }

    func modelNames(in entry: [String: Any]) -> [String] {
        guard let models = entry["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    func yamlMappingsEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        NSDictionary(dictionary: lhs).isEqual(to: rhs)
    }

    func oauthExcludedModels(from yaml: String) throws -> [String: Any] {
        let document = try parseMapping(yaml)
        return try XCTUnwrap(document["oauth-excluded-models"] as? [String: Any],
                             "ConfigComposer should emit top-level oauth-excluded-models")
    }

    func assertEmptyOverlayFileIsNoOp(_ overlayContents: String) throws {
        try withTemporaryAuthDirectory { authDir in
            let overlayURL = authDir.appendingPathComponent("overlay.yaml")
            try overlayContents.write(to: overlayURL, atomically: true, encoding: .utf8)

            let returnedPath = try writeMergedConfig(
                authDir: authDir,
                userConfigPath: overlayURL,
                upstreams: [zaiUpstream(apiKeys: ["k1"])],
                disabledOAuthProviders: ["claude"],
                managementSecretKey: "secret"
            )
            let contents = try String(contentsOfFile: returnedPath, encoding: .utf8)
            let document = try parseMapping(contents)
            let entries = try claudeAPIKeyEntries(from: contents)
            let exclusions = try oauthExcludedModels(from: contents)
            let remoteManagement = try XCTUnwrap(document["remote-management"] as? [String: Any])

            XCTAssertEqual(entries.first?["api-key"] as? String, "k1")
            XCTAssertEqual(exclusions["claude"] as? [String], ["*"])
            XCTAssertEqual(remoteManagement["secret-key"] as? String, "secret")
        }
    }
}
