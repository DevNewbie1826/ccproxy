import XCTest
@testable import CCProxy

final class ServerManagerConfigTests: XCTestCase {
    private var fixtureConfigPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/config.yaml")
            .path
    }

    func testMergedConfigIncludesRemoteManagementSecretWhenSet() {
        let defaults = UserDefaults.standard
        defaults.set("test-secret", forKey: "managementSecretKey")
        defer { defaults.removeObject(forKey: "managementSecretKey") }

        let manager = ServerManager()
        manager.bundledConfigPathOverride = fixtureConfigPath
        defer { manager.bundledConfigPathOverride = nil }
        let configPath = manager.getConfigPath()

        let contents: String
        do {
            contents = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            XCTFail("Failed to read merged config at \(configPath): \(error)")
            return
        }

        XCTAssertTrue(contents.contains("secret-key: \"test-secret\""))
    }

    func testMergedConfigAddsClaudeCompatibleUpstreamsForSupportedProviders() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)

        let fixtures: [(String, [String: Any])] = [
            ("zai-config-test.json", [
                "type": "zai",
                "email": "test",
                "api_key": "zai-test-key",
                "created": "2026-04-01T00:00:00Z"
            ]),
            ("kimi-config-test.json", [
                "type": "kimi",
                "email": "test",
                "api_key": "kimi-test-key",
                "created": "2026-04-01T00:00:00Z"
            ]),
            ("minimax-config-test.json", [
                "type": "minimax",
                "email": "test",
                "api_key": "minimax-test-key",
                "created": "2026-04-01T00:00:00Z"
            ])
        ]

        let files = fixtures.map { authDir.appendingPathComponent($0.0) }
        for (index, fixture) in fixtures.enumerated() {
            do {
                let data = try JSONSerialization.data(withJSONObject: fixture.1, options: .prettyPrinted)
                try data.write(to: files[index])
            } catch {
                XCTFail("Failed to write auth fixture \(files[index].lastPathComponent): \(error)")
                return
            }
        }
        defer {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }

        let manager = ServerManager()
        manager.bundledConfigPathOverride = fixtureConfigPath
        defer { manager.bundledConfigPathOverride = nil }
        let configPath = manager.getConfigPath()

        let contents: String
        do {
            contents = try String(contentsOfFile: configPath, encoding: .utf8)
        } catch {
            XCTFail("Failed to read merged config at \(configPath): \(error)")
            return
        }

        XCTAssertTrue(contents.contains("claude-api-key:"))
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
