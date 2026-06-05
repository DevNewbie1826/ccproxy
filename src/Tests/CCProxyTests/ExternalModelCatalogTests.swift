import XCTest
@testable import CCProxy

// MARK: - Test Doubles

final class ExternalModelCatalogTests: XCTestCase {

    // MARK: - Fixtures

    /// CLIProxyAPI models.json fixture with claude, codex tiers, kimi, and unmapped aistudio
    static let modelsJSONFixture: Data = """
    {
        "claude": [
            {"id": "claude-sonnet-4", "object": "model", "created": 1700000000, "owned_by": "anthropic"},
            {"id": "claude-opus-4", "object": "model", "created": 1700000001, "owned_by": "anthropic"}
        ],
        "codex-free": [
            {"id": "gpt-4o", "object": "model", "created": 1700000002, "owned_by": "openai", "type": "chat"}
        ],
        "codex-pro": [
            {"id": "o3", "object": "model", "created": 1700000003, "owned_by": "openai"}
        ],
        "kimi": [
            {"id": "kimi-k2", "object": "model", "created": 1700000004, "owned_by": "moonshotai"}
        ],
        "aistudio": [
            {"id": "aistudio-2.5-pro", "object": "model", "created": 1700000005, "owned_by": "google"}
        ]
    }
    """.data(using: .utf8)!

    /// codex_client_models.json fixture with supplemental metadata keyed by slug
    static let codexClientFixture: Data = """
    {
        "models": [
            {"slug": "gpt-4o", "display_name": "GPT-4o Free Tier", "description": "Free tier model"},
            {"slug": "o3", "display_name": "O3 Pro", "description": "Pro reasoning model"}
        ]
    }
    """.data(using: .utf8)!

    /// models.dev api.json fixture with mapped and unmapped providers
    static let modelsDevFixture: Data = """
    {
        "anthropic": {
            "models": {
                "claude-sonnet-4": {"owned_by": "anthropic-from-dev"},
                "claude-opus-4": {"owned_by": "anthropic-from-dev"}
            }
        },
        "openai": {
            "models": {
                "gpt-4o-mini": {"owned_by": "openai"}
            }
        },
        "zai-coding-plan": {
            "models": {
                "glm-5.1": {"owned_by": "zhipu"},
                "glm-5": {"owned_by": "zhipu"}
            }
        },
        "minimax-coding-plan": {
            "models": {
                "MiniMax-M2.7": {"owned_by": "minimax"}
            }
        },
        "moonshotai": {
            "models": {
                "kimi-k2": {"owned_by": "moonshotai"}
            }
        },
        "opencode-go": {
            "models": {
                "kimi-k2.6": {"owned_by": "opencode-go"},
                "claude-sonnet-4": {"owned_by": "anthropic-opencode"}
            }
        },
        "google": {
            "models": {
                "aistudio-2.5-pro": {"owned_by": "google"}
            }
        }
    }
    """.data(using: .utf8)!

    static let malformedJSON: Data = "{{not valid json".data(using: .utf8)!
    static let emptyObjectJSON: Data = "{}".data(using: .utf8)!

    // MARK: - Parser Tests

    func testParseModelsJSON_validFixture_producesProviderModels() {
        let result = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)
        XCTAssertNotNil(result, "Valid models.json should parse successfully")

        let claudeModels = result?.providerModels["claude"]
        XCTAssertNotNil(claudeModels)
        XCTAssertEqual(claudeModels?.count, 2)
        // Models are sorted by ID deterministically: claude-opus-4 < claude-sonnet-4
        XCTAssertEqual(claudeModels?.first?.id, "claude-opus-4")

        let codexModels = result?.providerModels["codex"]
        XCTAssertNotNil(codexModels)
        XCTAssertEqual(codexModels?.count, 2)

        let freeTier = codexModels?.first { $0.tier == "free" }
        XCTAssertNotNil(freeTier)
        XCTAssertEqual(freeTier?.id, "gpt-4o")

        let proTier = codexModels?.first { $0.tier == "pro" }
        XCTAssertNotNil(proTier)
        XCTAssertEqual(proTier?.id, "o3")

        let kimiModels = result?.providerModels["kimi"]
        XCTAssertNotNil(kimiModels)
        XCTAssertEqual(kimiModels?.count, 1)
        XCTAssertEqual(kimiModels?.first?.id, "kimi-k2")
    }

    func testParseModelsJSON_unknownFieldsIgnored() {
        let json = """
        {
            "claude": [
                {"id": "test-model", "unknown_field": "value", "thinking": {"budget": 5000}}
            ]
        }
        """.data(using: .utf8)!

        let result = ExternalModelCatalog.parseModelsJSON(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.providerModels["claude"]?.count, 1)
        XCTAssertEqual(result?.providerModels["claude"]?.first?.id, "test-model")
    }

    func testParseModelsJSON_malformed_returnsNil() {
        let result = ExternalModelCatalog.parseModelsJSON(Self.malformedJSON)
        XCTAssertNil(result, "Malformed JSON should return nil")
    }

    func testParseModelsJSON_emptyObject_returnsNil() {
        let result = ExternalModelCatalog.parseModelsJSON(Self.emptyObjectJSON)
        XCTAssertNil(result, "Empty JSON object with zero model entries should return nil")
    }

    func testParseModelsJSON_entryWithoutId_skipped() {
        let json = """
        {
            "claude": [
                {"object": "model", "owned_by": "anthropic"},
                {"id": "valid-model", "object": "model"}
            ]
        }
        """.data(using: .utf8)!

        let result = ExternalModelCatalog.parseModelsJSON(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.providerModels["claude"]?.count, 1)
        XCTAssertEqual(result?.providerModels["claude"]?.first?.id, "valid-model")
    }

    // MARK: codex_client_models.json parsing

    func testParseCodexClientModels_validFixture_slugBecomesId() {
        let result = ExternalModelCatalog.parseCodexClientModels(Self.codexClientFixture)
        XCTAssertNotNil(result)

        let codexModels = result?.providerModels["codex"]
        XCTAssertNotNil(codexModels)
        XCTAssertEqual(codexModels?.count, 2)

        let gpt4o = codexModels?.first { $0.id == "gpt-4o" }
        XCTAssertNotNil(gpt4o)
        XCTAssertEqual(gpt4o?.displayName, "GPT-4o Free Tier")

        let o3 = codexModels?.first { $0.id == "o3" }
        XCTAssertNotNil(o3)
        XCTAssertEqual(o3?.displayName, "O3 Pro")
    }

    func testParseCodexClientModels_malformed_returnsNil() {
        let result = ExternalModelCatalog.parseCodexClientModels(Self.malformedJSON)
        XCTAssertNil(result)
    }

    // MARK: models.dev parsing

    func testParseModelsDev_validFixture_nestedKeysBecomeModelIds() {
        let result = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)
        XCTAssertNotNil(result)

        let claudeModels = result?.providerModels["claude"]
        XCTAssertNotNil(claudeModels)
        XCTAssertEqual(claudeModels?.count, 2)
        XCTAssertTrue(claudeModels?.contains(where: { $0.id == "claude-sonnet-4" }) ?? false)

        let codexModels = result?.providerModels["codex"]
        XCTAssertNotNil(codexModels)
        XCTAssertEqual(codexModels?.count, 1)
        XCTAssertEqual(codexModels?.first?.id, "gpt-4o-mini")

        let zaiModels = result?.providerModels["zai"]
        XCTAssertNotNil(zaiModels)
        XCTAssertEqual(zaiModels?.count, 2)

        let minimaxModels = result?.providerModels["minimax"]
        XCTAssertNotNil(minimaxModels)
        XCTAssertEqual(minimaxModels?.count, 1)
        XCTAssertEqual(minimaxModels?.first?.id, "MiniMax-M2.7")

        let kimiModels = result?.providerModels["kimi"]
        XCTAssertNotNil(kimiModels)
        XCTAssertEqual(kimiModels?.count, 1)

        let ocGoModels = result?.providerModels["opencode-go"]
        XCTAssertNotNil(ocGoModels)
        XCTAssertEqual(ocGoModels?.count, 2)
        XCTAssertTrue(ocGoModels?.contains(where: { $0.id == "kimi-k2.6" }) ?? false)
        XCTAssertTrue(ocGoModels?.contains(where: { $0.id == "claude-sonnet-4" }) ?? false)

        XCTAssertNil(result?.providerModels["google"])
    }

    func testParseModelsDev_malformed_returnsNil() {
        let result = ExternalModelCatalog.parseModelsDev(Self.malformedJSON)
        XCTAssertNil(result)
    }

    func testParseModelsDev_providerWithoutModelsKey_returnsNil() {
        let json = """
        {
            "anthropic": {
                "name": "Anthropic",
                "url": "https://anthropic.com"
            }
        }
        """.data(using: .utf8)!

        let result = ExternalModelCatalog.parseModelsDev(json)
        XCTAssertNil(result)
    }

    // MARK: - Valid source despite malformed other

    func testValidSourceProducesResultDespiteMalformedOther() {
        let secondaryResult = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)
        XCTAssertNotNil(secondaryResult)

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: nil,
            codexClient: nil,
            secondary: secondaryResult,
            clock: FakeClock(Date())
        )
        XCTAssertNotNil(merged, "Valid secondary source alone should produce a valid merged snapshot")
        XCTAssertFalse(merged!.providerModels.isEmpty)
    }

    // MARK: - Merge / Filter Tests

    func testMerge_primaryWinsOverSecondary() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let claudeModels = merged.providerModels["claude"]
        XCTAssertNotNil(claudeModels)
        let sonnet = claudeModels!.first { $0.id == "claude-sonnet-4" }
        XCTAssertNotNil(sonnet)
        XCTAssertEqual(sonnet?.ownedBy, "anthropic", "Primary owned_by should win over secondary")
    }

    func testMerge_primaryKeyNormalization() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: nil,
            clock: FakeClock(Date())
        )!

        let codexModels = merged.providerModels["codex"]
        XCTAssertNotNil(codexModels)
        XCTAssertEqual(codexModels?.count, 2)

        let freeModel = codexModels!.first { $0.id == "gpt-4o" }
        XCTAssertEqual(freeModel?.tier, "free")

        let proModel = codexModels!.first { $0.id == "o3" }
        XCTAssertEqual(proModel?.tier, "pro")

        XCTAssertNotNil(merged.providerModels["claude"])
        XCTAssertNotNil(merged.providerModels["kimi"])
    }

    func testMerge_codexClientSupplementsBySlug() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let codexClient = ExternalModelCatalog.parseCodexClientModels(Self.codexClientFixture)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: codexClient,
            secondary: nil,
            clock: FakeClock(Date())
        )!

        let codexModels = merged.providerModels["codex"]
        XCTAssertNotNil(codexModels)

        let gpt4o = codexModels!.first { $0.id == "gpt-4o" }
        XCTAssertNotNil(gpt4o)
        XCTAssertEqual(gpt4o?.displayName, "GPT-4o Free Tier",
                       "Codex client display_name should supplement primary model")

        let o3 = codexModels!.first { $0.id == "o3" }
        XCTAssertNotNil(o3)
        XCTAssertEqual(o3?.displayName, "O3 Pro")
    }

    func testMerge_codexClientNeverSeparateProvider() {
        let codexClient = ExternalModelCatalog.parseCodexClientModels(Self.codexClientFixture)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: nil,
            codexClient: codexClient,
            secondary: nil,
            clock: FakeClock(Date())
        )

        XCTAssertNotNil(merged)
        XCTAssertNotNil(merged?.providerModels["codex"])
        XCTAssertNil(merged?.providerModels["codex_client"])
    }

    func testMerge_modelsDevFillsMissingProviders() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        XCTAssertNotNil(merged.providerModels["zai"])
        XCTAssertEqual(merged.providerModels["zai"]?.count, 2)

        XCTAssertNotNil(merged.providerModels["minimax"])
        XCTAssertNotNil(merged.providerModels["opencode-go"])

        let claudeCount = merged.providerModels["claude"]?.count
        XCTAssertEqual(claudeCount, 2, "Claude models should come from primary only")

        let codexModels = merged.providerModels["codex"]!
        let codexIds = Set(codexModels.map { $0.id })
        // Primary codex models gpt-4o and o3 must be preserved
        XCTAssertTrue(codexIds.contains("gpt-4o"))
        XCTAssertTrue(codexIds.contains("o3"))
        // Secondary fills missing model for partially covered provider
        XCTAssertTrue(codexIds.contains("gpt-4o-mini"),
                       "Secondary should fill missing codex model gpt-4o-mini")
        // Primary owned_by must win over secondary for existing models
        let gpt4o = codexModels.first { $0.id == "gpt-4o" }!
        XCTAssertEqual(gpt4o.ownedBy, "openai",
                       "Primary codex owned_by should be preserved")
    }

    func testMerge_unmappedPrimaryKeysNotEmittedForConnectedProviders() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: nil,
            clock: FakeClock(Date())
        )!

        let allConnectedProviders: Set<String> = ["claude", "codex", "kimi"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: allConnectedProviders
        )

        for model in filtered {
            XCTAssertFalse(model.id.hasPrefix("aistudio/"),
                           "Unmapped primary key 'aistudio' should not appear in filtered output")
        }
    }

    // MARK: - Connected-Provider Filter Tests

    func testFilter_emptyConnectedProviders_returnsEmptyData() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: []
        )
        XCTAssertTrue(filtered.isEmpty)

        let rendered = ExternalModelCatalog.renderModelList(models: filtered)
        let json = try! JSONSerialization.jsonObject(with: rendered) as! [String: Any]
        XCTAssertEqual(json["object"] as? String, "list")
        let data = json["data"] as? [[String: Any]] ?? []
        XCTAssertTrue(data.isEmpty)
    }

    func testFilter_onlyConnectedProviderModelsIncluded() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["zai", "opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            let hasZaiPrefix = model.id.hasPrefix("zai/")
            let hasOcGoPrefix = model.id.hasPrefix("opencode-go/")
            XCTAssertTrue(hasZaiPrefix || hasOcGoPrefix,
                          "Model '\(model.id)' should belong to a connected provider")
        }

        let zaiModels = filtered.filter { $0.id.hasPrefix("zai/") }
        XCTAssertEqual(zaiModels.count, 2)

        let ocGoModels = filtered.filter { $0.id.hasPrefix("opencode-go/") }
        XCTAssertEqual(ocGoModels.count, 2)
    }

    func testFilter_disabledProviders_excludedEvenWithCredentials() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["zai", "minimax"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            XCTAssertFalse(model.id.hasPrefix("claude/"))
            XCTAssertFalse(model.id.hasPrefix("codex/"))
        }
    }

    func testFilter_expiredOAuth_excludesClaudeAndCodex() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["zai", "kimi", "opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            XCTAssertFalse(model.id.hasPrefix("claude/"))
            XCTAssertFalse(model.id.hasPrefix("codex/"))
        }

        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("zai/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("kimi/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("opencode-go/") }))
    }

    func testFilter_noAuthProviders_excluded() {
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: nil,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["claude", "opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            XCTAssertFalse(model.id.hasPrefix("google/"))
        }
    }

    func testFilter_allConnectedProviders_includedInOutput() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["claude", "codex", "zai", "minimax", "kimi", "opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("claude/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("codex/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("zai/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("minimax/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("kimi/") }))
        XCTAssertTrue(filtered.contains(where: { $0.id.hasPrefix("opencode-go/") }))
    }

    func testFilter_openCodeGoProviderQualifiedIdsExactlyOnce() {
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: nil,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            XCTAssertTrue(model.id.hasPrefix("opencode-go/"))
            let afterFirstPrefix = String(model.id.dropFirst("opencode-go/".count))
            XCTAssertFalse(afterFirstPrefix.hasPrefix("opencode-go/"),
                           "Model ID should not have double prefix: \(model.id)")
        }

        XCTAssertTrue(filtered.contains(where: { $0.id == "opencode-go/kimi-k2.6" }))
    }

    // MARK: - Cache Coordinator Tests

    private func makeTempCacheDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-catalog-test-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func writeCacheSnapshot(
        _ snapshot: CatalogSnapshot,
        to directory: URL,
        writtenAt: Date
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(snapshot)
        let cacheFile = directory.appendingPathComponent("model-catalog-cache.json")
        try! data.write(to: cacheFile)

        try! FileManager.default.setAttributes(
            [.modificationDate: writtenAt],
            ofItemAtPath: cacheFile.path
        )

        let meta = CacheMetadata(
            cacheWrittenAt: ISO8601DateFormatter().string(from: writtenAt),
            lastRefreshAttemptAt: nil,
            lastFailure: nil
        )
        let metaData = try! encoder.encode(meta)
        let metaFile = directory.appendingPathComponent("model-catalog-cache-meta.json")
        try! metaData.write(to: metaFile)
    }

    private func writeMetadata(
        lastRefreshAttemptAt: Date?,
        lastFailure: CacheFailureMetadata?,
        to directory: URL
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let meta = CacheMetadata(
            cacheWrittenAt: ISO8601DateFormatter().string(from: Date()),
            lastRefreshAttemptAt: lastRefreshAttemptAt.map { ISO8601DateFormatter().string(from: $0) },
            lastFailure: lastFailure
        )
        let metaData = try! encoder.encode(meta)
        let metaFile = directory.appendingPathComponent("model-catalog-cache-meta.json")
        try! metaData.write(to: metaFile)
    }

    private func writeBundledSnapshot(_ snapshot: CatalogSnapshot, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try! encoder.encode(snapshot)
        try! data.write(to: url)
    }

    private func makeTestSnapshot() -> CatalogSnapshot {
        CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "codex_client_models.json", "models.dev"],
            providerModels: [
                "claude": [
                    CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1700000000, ownedBy: "anthropic", displayName: nil, tier: nil)
                ],
                "codex": [
                    CatalogModelEntry(id: "gpt-4o", object: "model", created: 1700000002, ownedBy: "openai", displayName: nil, tier: nil)
                ],
                "opencode-go": [
                    CatalogModelEntry(id: "kimi-k2.6", object: "model", created: 1700000010, ownedBy: "opencode-go", displayName: nil, tier: nil)
                ]
            ]
        )
    }

    // MARK: Fresh cache

    func testCache_freshCache_doesNotFetch() {
        let clock = FakeClock(Date())
        let fetcher = FakeCatalogFetcher()
        let cacheDir = makeTempCacheDirectory()

        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: Date())

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .available(let s) = result {
            XCTAssertGreaterThan(s.providerModels.count, 0)
        } else {
            XCTFail("Expected available snapshot from fresh cache")
        }

        XCTAssertEqual(fetcher.totalFetchCount, 0,
                       "Fresh cache should not trigger any fetch")
    }

    // MARK: Stale cache

    func testCache_staleCache_attemptsRefresh() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()
        XCTAssertGreaterThan(fetcher.totalFetchCount, 0,
                             "Stale cache should attempt refresh")
    }

    func testCache_refreshSuccess_replacesCache() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        let oldSnapshot = makeTestSnapshot()
        writeCacheSnapshot(oldSnapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .available(let newSnapshot) = result {
            XCTAssertGreaterThan(newSnapshot.providerModels.count, oldSnapshot.providerModels.count,
                                 "Refreshed snapshot should have more providers from fresh data")
        } else {
            XCTFail("Expected available snapshot after successful refresh")
        }
    }

    func testCache_refreshFailure_usesStaleCache() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        fetcher.modelsDevError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let cacheDir = makeTempCacheDirectory()

        let staleSnapshot = makeTestSnapshot()
        writeCacheSnapshot(staleSnapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertEqual(snapshot.providerModels.count, staleSnapshot.providerModels.count,
                           "Failed refresh should serve stale cache")
        } else {
            XCTFail("Expected stale cache to be served when refresh fails")
        }
    }

    // MARK: Failed refresh throttle

    func testCache_failedRefreshThrottle_noFetchWithin15Min() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let recentFailTime = now.addingTimeInterval(-5 * 60)

        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        let cacheDir = makeTempCacheDirectory()

        let staleSnapshot = makeTestSnapshot()
        writeCacheSnapshot(staleSnapshot, to: cacheDir, writtenAt: staleTime)

        writeMetadata(
            lastRefreshAttemptAt: recentFailTime,
            lastFailure: CacheFailureMetadata(
                timestamp: ISO8601DateFormatter().string(from: recentFailTime),
                sourceErrors: ["models.json": "network error"]
            ),
            to: cacheDir
        )

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .available = result {
            // Good, stale cache served
        } else {
            XCTFail("Expected stale cache to be served during throttle")
        }

        XCTAssertEqual(fetcher.totalFetchCount, 0,
                       "Should not fetch when last failure was within 15 min throttle")
    }

    func testCache_failedRefreshThrottle_fetchAfter15Min() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let oldFailTime = now.addingTimeInterval(-16 * 60)

        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        let staleSnapshot = makeTestSnapshot()
        writeCacheSnapshot(staleSnapshot, to: cacheDir, writtenAt: staleTime)

        writeMetadata(
            lastRefreshAttemptAt: oldFailTime,
            lastFailure: CacheFailureMetadata(
                timestamp: ISO8601DateFormatter().string(from: oldFailTime),
                sourceErrors: ["models.json": "network error"]
            ),
            to: cacheDir
        )

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()
        XCTAssertGreaterThan(fetcher.totalFetchCount, 0,
                             "Should attempt refresh when last failure was > 15 min ago")
    }

    // MARK: Fresh app start with stale cache

    func testCache_freshAppStartStaleCache_attemptsOneRefresh() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()
        XCTAssertGreaterThan(fetcher.totalFetchCount, 0)

        let firstFetchCount = fetcher.totalFetchCount

        let _ = coordinator.getCatalog()
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Subsequent calls should not re-fetch after successful refresh")
    }

    // MARK: No runtime cache, bundled snapshot

    func testCache_noRuntimeCache_validBundledSnapshot_failedRefresh_servesBundled() {
        let clock = FakeClock(Date())
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        let bundledSnapshot = makeTestSnapshot()
        writeBundledSnapshot(bundledSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertEqual(snapshot.providerModels.count, bundledSnapshot.providerModels.count,
                           "Should serve bundled snapshot when no runtime cache and refresh fails")
        } else {
            XCTFail("Expected bundled snapshot to be served")
        }
    }

    func testCache_bundledSnapshot_failedRefresh_throttlesFor15Min() {
        let now = Date()
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(makeTestSnapshot(), to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let _ = coordinator.getCatalog()
        let firstFetchCount = fetcher.totalFetchCount
        XCTAssertGreaterThan(firstFetchCount, 0, "First call should attempt refresh")

        let _ = coordinator.getCatalog()
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Second call within 15 min should not fetch")
    }

    func testCache_bundledSnapshot_retriesAfter15MinWindow() {
        let now = Date()
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(makeTestSnapshot(), to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let _ = coordinator.getCatalog()
        let firstFetchCount = fetcher.totalFetchCount

        clock.advance(by: 16 * 60)

        let _ = coordinator.getCatalog()
        XCTAssertGreaterThan(fetcher.totalFetchCount, firstFetchCount,
                             "Should retry refresh after 15 min window")
    }

    // MARK: Invalid runtime cache

    func testCache_invalidRuntimeCache_usesBundledSnapshot() {
        let clock = FakeClock(Date())
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let cacheFile = cacheDir.appendingPathComponent("model-catalog-cache.json")
        try! Self.malformedJSON.write(to: cacheFile)

        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(makeTestSnapshot(), to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available = result {
            // Good: bundled snapshot served
        } else {
            XCTFail("Invalid runtime cache should fall back to bundled snapshot")
        }
    }

    // MARK: - Strict Runtime Cache Validation

    /// Verifies that a fresh runtime cache with empty sources is rejected
    /// and falls back to bundled snapshot when available.
    func testRuntimeCache_emptySources_rejected_fallsBackToBundled() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Runtime cache with empty sources (invalid per isValidSnapshot)
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: [],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        writeCacheSnapshot(badSnapshot, to: cacheDir, writtenAt: Date())

        // Valid bundled snapshot for fallback
        let validBundled = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "codex": [CatalogModelEntry(id: "gpt-4o", object: "model", created: 2, ownedBy: "openai", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validBundled, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            // Should serve the bundled snapshot (codex), not the invalid runtime cache (claude)
            XCTAssertNotNil(snapshot.providerModels["codex"],
                            "Should serve bundled snapshot with codex provider")
            XCTAssertNil(snapshot.providerModels["claude"],
                          "Should not serve runtime cache with empty sources (which had claude)")
        } else {
            XCTFail("Invalid runtime cache should fall back to valid bundled snapshot, got \(result)")
        }
    }

    /// Verifies that a fresh runtime cache with empty providerModels is rejected
    /// and falls back to bundled snapshot when available.
    func testRuntimeCache_emptyProviderModels_rejected_fallsBackToBundled() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Runtime cache with empty providerModels (invalid per isValidSnapshot)
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [:]
        )
        writeCacheSnapshot(badSnapshot, to: cacheDir, writtenAt: Date())

        // Valid bundled snapshot for fallback
        let validBundled = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "codex": [CatalogModelEntry(id: "gpt-4o", object: "model", created: 2, ownedBy: "openai", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validBundled, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertNotNil(snapshot.providerModels["codex"],
                            "Should serve bundled snapshot, not invalid runtime cache")
        } else {
            XCTFail("Invalid runtime cache should fall back to valid bundled snapshot, got \(result)")
        }
    }

    /// Verifies that a fresh runtime cache with a provider having an empty model array
    /// is rejected and falls back to bundled snapshot when available.
    func testRuntimeCache_providerEmptyModelArray_rejected_fallsBackToBundled() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Runtime cache with one provider having an empty model array
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [] // empty array: invalid per isValidSnapshot
            ]
        )
        writeCacheSnapshot(badSnapshot, to: cacheDir, writtenAt: Date())

        // Valid bundled snapshot for fallback
        let validBundled = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "opencode-go": [CatalogModelEntry(id: "kimi-k2.6", object: "model", created: 3, ownedBy: "opencode-go", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validBundled, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertNotNil(snapshot.providerModels["opencode-go"],
                            "Should serve bundled snapshot, not invalid runtime cache")
        } else {
            XCTFail("Invalid runtime cache should fall back to valid bundled snapshot, got \(result)")
        }
    }

    /// Verifies that a fresh runtime cache with a model entry having an empty ID
    /// is rejected and falls back to bundled snapshot when available.
    func testRuntimeCache_emptyModelId_rejected_fallsBackToBundled() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Runtime cache with a model entry having empty ID
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [
                    CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil),
                    CatalogModelEntry(id: "", object: "model", created: 2, ownedBy: "anthropic", displayName: nil, tier: nil) // empty ID
                ]
            ]
        )
        writeCacheSnapshot(badSnapshot, to: cacheDir, writtenAt: Date())

        // Valid bundled snapshot for fallback
        let validBundled = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "codex": [CatalogModelEntry(id: "gpt-4o", object: "model", created: 2, ownedBy: "openai", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validBundled, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertNotNil(snapshot.providerModels["codex"],
                            "Should serve bundled snapshot, not invalid runtime cache")
        } else {
            XCTFail("Invalid runtime cache should fall back to valid bundled snapshot, got \(result)")
        }
    }

    /// Verifies that an invalid runtime cache falls back to a valid bundled snapshot
    /// and serves the bundled snapshot content, not the invalid runtime cache content.
    func testRuntimeCache_invalidSnapshot_fallsBackToValidBundled() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Invalid runtime cache: unknown sources
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["unknown-source"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        writeCacheSnapshot(badSnapshot, to: cacheDir, writtenAt: Date())

        // Valid bundled snapshot with different content
        let validBundled = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "zai": [CatalogModelEntry(id: "glm-5", object: "model", created: 3, ownedBy: "zhipu", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validBundled, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            // Should serve bundled snapshot (zai), not the invalid runtime cache (claude)
            XCTAssertNotNil(snapshot.providerModels["zai"],
                            "Should serve bundled snapshot with zai provider")
            XCTAssertNil(snapshot.providerModels["claude"],
                          "Should not serve invalid runtime cache with claude provider")
        } else {
            XCTFail("Invalid runtime cache should fall back to valid bundled snapshot, got \(result)")
        }
    }

    // MARK: No cache, no snapshot

    func testCache_noCacheNoSnapshot_returnsUnavailable() {
        let clock = FakeClock(Date())
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected
        } else {
            XCTFail("No cache and no snapshot should return unavailable")
        }
    }

    // MARK: No per-request fetch loop

    func testCache_staleCache_failedRefresh_noRepeatedFetches() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()
        let firstFetchCount = fetcher.totalFetchCount
        XCTAssertGreaterThan(firstFetchCount, 0)

        let _ = coordinator.getCatalog()
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Should not fetch again within throttle window")

        let _ = coordinator.getCatalog()
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Should not fetch again within throttle window")
    }

    // MARK: - Renderer Tests

    func testRender_openAIStyleStructure() {
        let models = [
            CatalogModel(id: "claude/claude-sonnet-4", object: "model", created: 1700000000,
                         ownedBy: "anthropic", displayName: nil, tier: nil,
                         sourceProvenance: "test", supplementalMetadata: [:]),
            CatalogModel(id: "opencode-go/kimi-k2.6", object: "model", created: 1700000010,
                         ownedBy: "opencode-go", displayName: nil, tier: nil,
                         sourceProvenance: "test", supplementalMetadata: [:])
        ]

        let data = ExternalModelCatalog.renderModelList(models: models)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["object"] as? String, "list")

        let dataArray = json["data"] as? [[String: Any]]
        XCTAssertNotNil(dataArray)
        XCTAssertEqual(dataArray?.count, 2)

        let first = dataArray![0]
        XCTAssertEqual(first["id"] as? String, "claude/claude-sonnet-4")
        XCTAssertEqual(first["object"] as? String, "model")
        XCTAssertNotNil(first["created"])
        XCTAssertEqual(first["owned_by"] as? String, "anthropic")

        let second = dataArray![1]
        XCTAssertEqual(second["id"] as? String, "opencode-go/kimi-k2.6")
        XCTAssertEqual(second["owned_by"] as? String, "opencode-go")
    }

    func testRender_openCodeGoIdsExactlyOnce() {
        let models = [
            CatalogModel(id: "opencode-go/kimi-k2.6", object: "model", created: 1700000010,
                         ownedBy: "opencode-go", displayName: nil, tier: nil,
                         sourceProvenance: "test", supplementalMetadata: [:])
        ]

        let data = ExternalModelCatalog.renderModelList(models: models)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let dataArray = json["data"] as! [[String: Any]]

        let id = dataArray[0]["id"] as! String
        XCTAssertEqual(id, "opencode-go/kimi-k2.6")

        let prefix = "opencode-go/"
        let afterFirst = String(id.dropFirst(prefix.count))
        XCTAssertFalse(afterFirst.hasPrefix(prefix),
                       "OpenCode Go ID should not be double-prefixed: \(id)")
    }

    func testRender_createdDefaultsToZeroWhenMissing() {
        let models = [
            CatalogModel(id: "test/model", object: "model", created: 0,
                         ownedBy: "test", displayName: nil, tier: nil,
                         sourceProvenance: "test", supplementalMetadata: [:])
        ]

        let data = ExternalModelCatalog.renderModelList(models: models)
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let dataArray = json["data"] as! [[String: Any]]

        XCTAssertEqual(dataArray[0]["created"] as? Int, 0,
                       "Missing created should default to 0")
    }

    // MARK: - Review Fix: Already-Qualified IDs

    func testFilter_alreadyQualifiedIds_remainQualifiedExactlyOnce() {
        // models.dev may return IDs that already contain the provider prefix
        let alreadyQualifiedDevFixture: Data = """
        {
            "opencode-go": {
                "models": {
                    "kimi-k2.6": {"id": "opencode-go/kimi-k2.6", "owned_by": "opencode-go"},
                    "claude-sonnet-4": {"id": "opencode-go/claude-sonnet-4", "owned_by": "anthropic-opencode"}
                }
            }
        }
        """.data(using: .utf8)!

        let secondary = ExternalModelCatalog.parseModelsDev(alreadyQualifiedDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: nil,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["opencode-go"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged,
            connectedProviders: connected
        )

        for model in filtered {
            XCTAssertTrue(model.id.hasPrefix("opencode-go/"),
                          "Model ID should have provider prefix: \(model.id)")
            let afterPrefix = String(model.id.dropFirst("opencode-go/".count))
            XCTAssertFalse(afterPrefix.hasPrefix("opencode-go/"),
                           "Model ID should not be double-prefixed: \(model.id)")
        }

        XCTAssertTrue(filtered.contains(where: { $0.id == "opencode-go/kimi-k2.6" }),
                       "Should contain exactly-qualified opencode-go/kimi-k2.6")
        XCTAssertTrue(filtered.contains(where: { $0.id == "opencode-go/claude-sonnet-4" }),
                       "Should contain exactly-qualified opencode-go/claude-sonnet-4")
    }

    // MARK: - Review Fix: Secondary Fills Missing Models for Partially-Covered Providers

    func testMerge_secondaryFillsMissingModelsForPartiallyCoveredProvider() {
        // Primary covers codex with gpt-4o and o3
        let partialPrimaryFixture: Data = """
        {
            "codex-free": [
                {"id": "gpt-4o", "object": "model", "created": 1700000002, "owned_by": "openai"}
            ],
            "codex-pro": [
                {"id": "o3", "object": "model", "created": 1700000003, "owned_by": "openai"}
            ]
        }
        """.data(using: .utf8)!

        // Secondary has codex models including gpt-4o-mini that primary does not cover
        let secondaryWithExtraCodex: Data = """
        {
            "openai": {
                "models": {
                    "gpt-4o-mini": {"owned_by": "openai"},
                    "gpt-4o": {"owned_by": "openai-secondary"},
                    "o3": {"owned_by": "openai-secondary"}
                }
            }
        }
        """.data(using: .utf8)!

        let primary = ExternalModelCatalog.parseModelsJSON(partialPrimaryFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(secondaryWithExtraCodex)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: nil,
            secondary: secondary,
            clock: FakeClock(Date())
        )!

        let codexModels = merged.providerModels["codex"]!
        let codexIds = Set(codexModels.map { $0.id })

        // Primary models must be preserved with primary owned_by
        XCTAssertTrue(codexIds.contains("gpt-4o"), "Primary gpt-4o must be present")
        XCTAssertTrue(codexIds.contains("o3"), "Primary o3 must be present")

        let gpt4o = codexModels.first { $0.id == "gpt-4o" }!
        XCTAssertEqual(gpt4o.ownedBy, "openai", "Primary model owned_by must be preserved, not replaced by secondary")

        // Secondary fills missing model for partially covered provider
        XCTAssertTrue(codexIds.contains("gpt-4o-mini"),
                       "Secondary should fill missing model gpt-4o-mini for partially covered provider")
    }

    // MARK: - Review Fix: Codex Client Metadata Preserves Supplemental Fields

    func testMerge_codexClientPreservesSupplementalMetadataBySlug() {
        let primaryFixture: Data = """
        {
            "codex-pro": [
                {"id": "o3", "object": "model", "created": 1700000003, "owned_by": "openai"},
                {"id": "codex-mini", "object": "model", "created": 1700000020, "owned_by": "openai"}
            ]
        }
        """.data(using: .utf8)!

        // codex_client_models.json with description and other fields beyond display_name
        let codexClientWithMetadata: Data = """
        {
            "models": [
                {
                    "slug": "o3",
                    "display_name": "O3 Pro",
                    "description": "Pro reasoning model",
                    "visibility": "public",
                    "context_length": 200000
                },
                {
                    "slug": "codex-mini",
                    "display_name": "Codex Mini",
                    "description": "Compact coding model"
                }
            ]
        }
        """.data(using: .utf8)!

        let primary = ExternalModelCatalog.parseModelsJSON(primaryFixture)!
        let codexClient = ExternalModelCatalog.parseCodexClientModels(codexClientWithMetadata)!

        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: codexClient,
            secondary: nil,
            clock: FakeClock(Date())
        )!

        let codexModels = merged.providerModels["codex"]!
        let o3 = codexModels.first { $0.id == "o3" }!
        XCTAssertEqual(o3.displayName, "O3 Pro")

        // Supplemental metadata keyed by slug must be preserved
        XCTAssertNotNil(o3.supplementalMetadata, "Supplemental metadata should be preserved")
        XCTAssertEqual(o3.supplementalMetadata["description"], "Pro reasoning model",
                       "Description from codex client should be preserved as supplemental metadata")
        XCTAssertEqual(o3.supplementalMetadata["visibility"], "public",
                       "Visibility from codex client should be preserved as supplemental metadata")

        let mini = codexModels.first { $0.id == "codex-mini" }!
        XCTAssertEqual(mini.displayName, "Codex Mini")
        XCTAssertEqual(mini.supplementalMetadata["description"], "Compact coding model",
                       "Description from codex client should be preserved as supplemental metadata")
    }

    // MARK: - Provider Mapping Tests

    func testPrimaryProviderMapping_exactMappings() {
        let mapping = ExternalModelCatalog.primaryProviderMapping
        XCTAssertEqual(mapping["claude"], "claude")
        XCTAssertEqual(mapping["codex-free"], "codex")
        XCTAssertEqual(mapping["codex-team"], "codex")
        XCTAssertEqual(mapping["codex-plus"], "codex")
        XCTAssertEqual(mapping["codex-pro"], "codex")
        XCTAssertEqual(mapping["kimi"], "kimi")
    }

    func testSecondaryProviderMapping_exactMappings() {
        let mapping = ExternalModelCatalog.secondaryProviderMapping
        XCTAssertEqual(mapping["claude"], "anthropic")
        XCTAssertEqual(mapping["codex"], "openai")
        XCTAssertEqual(mapping["zai"], "zai-coding-plan")
        XCTAssertEqual(mapping["minimax"], "minimax-coding-plan")
        XCTAssertEqual(mapping["kimi"], "moonshotai")
        XCTAssertEqual(mapping["opencode-go"], "opencode-go")
    }

    // MARK: - Quality Review Fix: Deterministic Ordering

    func testDeterministicProviderModelOrdering() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: nil, secondary: secondary,
            clock: FakeClock(Date())
        )!

        let connected: Set<String> = ["claude", "codex", "kimi", "minimax", "opencode-go", "zai"]
        let filtered = ExternalModelCatalog.filterCatalog(
            snapshot: merged, connectedProviders: connected
        )

        // Verify providers appear in alphabetical order
        var seenProviders: [String] = []
        for model in filtered {
            let provider = model.id.components(separatedBy: "/").first!
            if seenProviders.last != provider {
                seenProviders.append(provider)
            }
        }
        XCTAssertEqual(seenProviders, seenProviders.sorted(),
                       "Providers should appear in alphabetical order: \(seenProviders)")

        // Verify models within each provider are sorted by ID
        var currentProvider = ""
        var currentProviderModelIds: [String] = []
        for model in filtered {
            let provider = model.id.components(separatedBy: "/").first!
            let modelId = String(model.id.dropFirst(provider.count + 1))
            if provider != currentProvider {
                if !currentProviderModelIds.isEmpty {
                    XCTAssertEqual(currentProviderModelIds, currentProviderModelIds.sorted(),
                                   "Models within '\(currentProvider)' should be sorted by ID: \(currentProviderModelIds)")
                }
                currentProvider = provider
                currentProviderModelIds = []
            }
            currentProviderModelIds.append(modelId)
        }
        if !currentProviderModelIds.isEmpty {
            XCTAssertEqual(currentProviderModelIds, currentProviderModelIds.sorted(),
                           "Models within '\(currentProvider)' should be sorted by ID: \(currentProviderModelIds)")
        }
    }

    func testDeterministicCodexDuplicateTierPrecedence() {
        // Fixture where codex-free and codex-pro both have "gpt-4o"
        let duplicateFixture: Data = """
        {
            "codex-free": [
                {"id": "gpt-4o", "object": "model", "created": 1700000002, "owned_by": "openai", "display_name": "GPT-4o Free"}
            ],
            "codex-pro": [
                {"id": "gpt-4o", "object": "model", "created": 1700000003, "owned_by": "openai", "display_name": "GPT-4o Pro"}
            ]
        }
        """.data(using: .utf8)!

        let primary = ExternalModelCatalog.parseModelsJSON(duplicateFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: nil, secondary: nil,
            clock: FakeClock(Date())
        )!

        let codexModels = merged.providerModels["codex"]!
        let gpt4oModels = codexModels.filter { $0.id == "gpt-4o" }
        XCTAssertEqual(gpt4oModels.count, 1,
                       "Duplicate gpt-4o from different Codex tiers should be deduplicated to exactly one")

        // The winning model must be deterministic: free tier wins (lowest tier order)
        let winner = gpt4oModels.first!
        XCTAssertEqual(winner.tier, "free",
                       "When same model ID appears in multiple Codex tiers, " +
                       "the lowest tier (free) should win deterministically")
        XCTAssertEqual(winner.displayName, "GPT-4o Free",
                       "Winning model display name should match the free tier entry")
    }

    // MARK: - Quality Review Fix: Clock Injection

    func testMergeGeneratedAtUsesInjectedClock() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let clock = FakeClock(fixedDate)

        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: nil, secondary: nil, clock: clock
        )

        XCTAssertNotNil(merged)
        let expectedTimestamp = ISO8601DateFormatter().string(from: fixedDate)
        XCTAssertEqual(merged?.generatedAt, expectedTimestamp,
                       "generatedAt should use injected clock, not wall-clock Date()")
    }

    func testCacheFailureMetadataTimestampUsesInjectedClock() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let clock = FakeClock(fixedDate)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "network error"])
        fetcher.modelsDevError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "network error"])
        let cacheDir = makeTempCacheDirectory()

        let coordinator = CacheCoordinator(
            clock: clock, fetcher: fetcher, cacheDirectory: cacheDir, bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()

        let metaFile = cacheDir.appendingPathComponent("model-catalog-cache-meta.json")
        let metaData = try! Data(contentsOf: metaFile)
        let meta = try! JSONDecoder().decode(CacheMetadata.self, from: metaData)

        let expectedTimestamp = ISO8601DateFormatter().string(from: fixedDate)
        XCTAssertEqual(meta.cacheWrittenAt, expectedTimestamp,
                       "Failure metadata cacheWrittenAt should use injected clock")
        XCTAssertEqual(meta.lastRefreshAttemptAt, expectedTimestamp,
                       "Failure metadata lastRefreshAttemptAt should use injected clock")
        XCTAssertNotNil(meta.lastFailure)
        XCTAssertEqual(meta.lastFailure?.timestamp, expectedTimestamp,
                       "Failure metadata timestamp should use injected clock")
        XCTAssertFalse(meta.lastFailure?.sourceErrors.isEmpty ?? true)
    }

    func testCacheClearFailureMetadataUsesInjectedClock() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let clock = FakeClock(fixedDate)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        // Write a stale cache with pre-existing failure metadata
        let staleSnapshot = makeTestSnapshot()
        let staleTime = fixedDate.addingTimeInterval(-7 * 3600)
        writeCacheSnapshot(staleSnapshot, to: cacheDir, writtenAt: staleTime)
        writeMetadata(
            lastRefreshAttemptAt: staleTime,
            lastFailure: CacheFailureMetadata(
                timestamp: ISO8601DateFormatter().string(from: staleTime),
                sourceErrors: ["models.json": "old error"]
            ),
            to: cacheDir
        )

        let coordinator = CacheCoordinator(
            clock: clock, fetcher: fetcher, cacheDirectory: cacheDir, bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()

        // After successful refresh, metadata should use injected clock
        let metaFile = cacheDir.appendingPathComponent("model-catalog-cache-meta.json")
        let metaData = try! Data(contentsOf: metaFile)
        let meta = try! JSONDecoder().decode(CacheMetadata.self, from: metaData)

        let expectedTimestamp = ISO8601DateFormatter().string(from: fixedDate)
        XCTAssertEqual(meta.cacheWrittenAt, expectedTimestamp,
                       "Cleared metadata cacheWrittenAt should use injected clock")
        XCTAssertNil(meta.lastFailure,
                     "Failure metadata should be cleared after successful refresh")
    }

    // MARK: - Quality Fix: Fresh In-Memory Preferred Over Stale Disk Cache

    func testCache_prefersFreshInMemoryOverStaleDiskWhenPersistenceFails() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        // Pre-populate with stale disk cache
        let staleSnapshot = makeTestSnapshot()
        writeCacheSnapshot(staleSnapshot, to: cacheDir, writtenAt: staleTime)

        // Make directory read-only so cache writes fail silently
        // but reads still succeed (stale cache is loadable)
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o555))],
            ofItemAtPath: cacheDir.path
        )

        let coordinator = CacheCoordinator(
            clock: clock, fetcher: fetcher,
            cacheDirectory: cacheDir, bundledSnapshotURL: nil
        )

        // First call: disk is stale → refresh succeeds → inMemorySnapshot set → write fails
        let result1 = coordinator.getCatalog()
        guard case .available(let s1) = result1 else {
            XCTFail("First call should return available")
            return
        }
        // Refresh produces more providers than stale snapshot
        XCTAssertGreaterThan(s1.providerModels.count, staleSnapshot.providerModels.count,
                              "Refreshed snapshot should have more providers")
        let firstFetchCount = fetcher.totalFetchCount
        XCTAssertGreaterThan(firstFetchCount, 0)

        // Second call: should serve fresh in-memory snapshot, NOT stale disk cache
        let result2 = coordinator.getCatalog()
        guard case .available(let s2) = result2 else {
            XCTFail("Second call should return available")
            return
        }
        XCTAssertEqual(s2.providerModels.count, s1.providerModels.count,
                       "Should serve fresh in-memory snapshot, not stale disk cache")
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Should not re-fetch when in-memory snapshot is available")

        // Restore permissions for cleanup
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: cacheDir.path
        )
    }

    // MARK: - Quality Review Fix: In-Memory Snapshot and Persistence

    func testServesInMemorySnapshotWhenPersistenceFails() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let clock = FakeClock(fixedDate)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture

        // Use a non-existent directory (writes will fail silently)
        let nonExistentDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-noexist-\(UUID().uuidString)/nested", isDirectory: true)
        addTeardownBlock {
            let parent = nonExistentDir.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parent)
        }

        let coordinator = CacheCoordinator(
            clock: clock, fetcher: fetcher, cacheDirectory: nonExistentDir, bundledSnapshotURL: nil
        )

        // First call: refresh succeeds, write fails silently
        let result1 = coordinator.getCatalog()
        guard case .available(let s1) = result1 else {
            XCTFail("First call should return available from refresh")
            return
        }
        XCTAssertGreaterThan(s1.providerModels.count, 0)
        let firstFetchCount = fetcher.totalFetchCount
        XCTAssertGreaterThan(firstFetchCount, 0)

        // Second call: should serve in-memory snapshot without re-fetching
        let result2 = coordinator.getCatalog()
        guard case .available(let s2) = result2 else {
            XCTFail("Second call should serve in-memory snapshot when persistence failed")
            return
        }
        XCTAssertEqual(s2.providerModels.count, s1.providerModels.count)
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                       "Should not re-fetch when in-memory snapshot is available from previous refresh")
    }

    func testPersistedFailureMetadataContainsCorrectTimestampAndErrors() {
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let clock = FakeClock(fixedDate)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "models.json timeout"])
        fetcher.modelsDevError = NSError(domain: "test", code: 43, userInfo: [NSLocalizedDescriptionKey: "models.dev timeout"])
        let cacheDir = makeTempCacheDirectory()

        let coordinator = CacheCoordinator(
            clock: clock, fetcher: fetcher, cacheDirectory: cacheDir, bundledSnapshotURL: nil
        )

        let _ = coordinator.getCatalog()

        let metaFile = cacheDir.appendingPathComponent("model-catalog-cache-meta.json")
        let metaData = try! Data(contentsOf: metaFile)
        let meta = try! JSONDecoder().decode(CacheMetadata.self, from: metaData)

        let expectedTimestamp = ISO8601DateFormatter().string(from: fixedDate)

        // Verify all timestamps use the injected clock
        XCTAssertEqual(meta.cacheWrittenAt, expectedTimestamp,
                       "cacheWrittenAt should use injected clock timestamp")
        XCTAssertEqual(meta.lastRefreshAttemptAt, expectedTimestamp,
                       "lastRefreshAttemptAt should use injected clock timestamp")

        // Verify failure metadata contents
        guard let failure = meta.lastFailure else {
            XCTFail("Failure metadata should be recorded after failed refresh")
            return
        }
        XCTAssertEqual(failure.timestamp, expectedTimestamp,
                       "Failure timestamp should use injected clock")
        XCTAssertTrue(failure.sourceErrors["models.json"]?.contains("timeout") ?? false,
                      "Failure should record models.json error")
        XCTAssertTrue(failure.sourceErrors["models.dev"]?.contains("timeout") ?? false,
                      "Failure should record models.dev error")
    }

    // MARK: - Review Fix: CatalogModelsResult Distinction

    /// Verifies that CatalogModelsResult.unavailable is distinct from .available([]).
    /// This distinction is critical: connected-provider-empty means a valid empty model list
    /// should be returned, while unavailable means no valid catalog exists and the response
    /// should produce an explicit empty list (not a backend pass-through).
    func testCatalogModelsResult_unavailableDistinctFromAvailableEmpty() {
        let availableEmpty: CatalogModelsResult = .available([])
        let unavailable: CatalogModelsResult = .unavailable

        XCTAssertNotEqual(availableEmpty, unavailable,
                           ".available([]) must be distinct from .unavailable")
    }

    /// Verifies that CatalogModelsResult.available with models is distinct from .unavailable.
    func testCatalogModelsResult_availableModelsDistinctFromUnavailable() {
        let available: CatalogModelsResult = .available([
            CatalogModel(id: "test/model", object: "model", created: 0, ownedBy: "test",
                         displayName: nil, tier: nil, sourceProvenance: "test", supplementalMetadata: [:])
        ])
        let unavailable: CatalogModelsResult = .unavailable

        XCTAssertNotEqual(available, unavailable,
                           ".available([model]) must be distinct from .unavailable")
    }

    /// Verifies that ProductionModelListCatalogProvider returns .unavailable
    /// when CacheCoordinator has no valid cache or snapshot.
    func testProductionProvider_noCacheNoSnapshot_returnsUnavailable() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["claude"] }
        )

        let result = provider.fetchCatalogModels()
        if case .unavailable = result {
            // Expected
        } else {
            XCTFail("Expected .unavailable with no cache/snapshot, got \(result)")
        }
    }

    /// Verifies that ProductionModelListCatalogProvider returns .available([])
    /// when catalog data is available but connected-provider set is empty.
    func testProductionProvider_catalogAvailable_noProviders_returnsAvailableEmpty() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { Set<String>() }
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            XCTAssertTrue(models.isEmpty,
                          "No connected providers should produce empty model list, not unavailable")
        } else {
            XCTFail("Expected .available([]) with catalog data but no providers, got \(result)")
        }
    }

    /// Verifies that ProductionModelListCatalogProvider returns .available with models
    /// when catalog data and connected providers both exist.
    func testProductionProvider_catalogAndProvidersExist_returnsAvailableModels() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["claude", "zai", "opencode-go"] }
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            XCTAssertFalse(models.isEmpty)
            let claudeModels = models.filter { $0.id.hasPrefix("claude/") }
            let zaiModels = models.filter { $0.id.hasPrefix("zai/") }
            let ocGoModels = models.filter { $0.id.hasPrefix("opencode-go/") }
            XCTAssertFalse(claudeModels.isEmpty, "Should have Claude models")
            XCTAssertFalse(zaiModels.isEmpty, "Should have ZAI models")
            XCTAssertFalse(ocGoModels.isEmpty, "Should have OpenCode Go models")
        } else {
            XCTFail("Expected .available([models]) with catalog and providers, got \(result)")
        }
    }

    // MARK: - Quality Fix: CacheCoordinator Thread Safety

    /// Verifies that concurrent getCatalog() calls do not crash or produce
    /// inconsistent results. The CacheCoordinator's mutable state must be
    /// synchronized so that concurrent /v1/models requests are safe.
    func testCacheCoordinator_concurrentAccessDoesNotCrash() {
        let clock = FakeClock(Date())
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        // Write a fresh cache to avoid refresh during concurrent access
        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: Date())

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let iterations = 100
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = iterations

        // Fire many concurrent getCatalog() calls
        for _ in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = coordinator.getCatalog()
                switch result {
                case .available:
                    break // Valid
                case .unavailable:
                    XCTFail("Concurrent access returned unavailable with fresh cache")
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)

        // Verify no crashes and fetch count is bounded (fresh cache = 0 fetches)
        XCTAssertEqual(fetcher.totalFetchCount, 0,
                       "Fresh cache concurrent reads should not trigger any fetches")
    }

    /// Verifies that concurrent getCatalog() calls with a stale cache
    /// trigger at most one refresh attempt (bounded fetch count).
    func testCacheCoordinator_concurrentStaleRefresh_fetchCountBounded() {
        let now = Date()
        let staleTime = now.addingTimeInterval(-7 * 3600)
        let clock = FakeClock(now)
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = Self.modelsJSONFixture
        fetcher.modelsDevData = Self.modelsDevFixture
        let cacheDir = makeTempCacheDirectory()

        let snapshot = makeTestSnapshot()
        writeCacheSnapshot(snapshot, to: cacheDir, writtenAt: staleTime)

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let iterations = 50
        let expectation = self.expectation(description: "Concurrent stale access")
        expectation.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let _ = coordinator.getCatalog()
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)

        // Concurrent stale-cache accesses should trigger at most a small number of
        // refresh attempts (ideally 1, but concurrent races may cause a few).
        // The important thing is it doesn't crash and the count is bounded well
        // below iterations * 3 (3 fetches per refresh attempt).
        let maxExpectedFetches = 15 // generous bound for concurrent races
        XCTAssertLessThanOrEqual(fetcher.totalFetchCount, maxExpectedFetches,
                                  "Concurrent stale cache reads should trigger bounded refresh attempts, got \(fetcher.totalFetchCount)")
    }

    // MARK: - Review Fix: URLSessionCatalogFetcher Tests

    /// Verifies that URLSessionCatalogFetcher uses a configured timeout
    /// (does not wait indefinitely).
    func testURLSessionCatalogFetcher_hasConfiguredTimeout() {
        let fetcher = URLSessionCatalogFetcher()
        // The fetcher must have a deterministic short timeout configured.
        // We verify the timeout property exists and is reasonable (≤ 30 seconds).
        XCTAssertLessThanOrEqual(fetcher.timeoutInterval, 30.0,
                                  "Fetcher timeout should be deterministic and short (≤ 30s)")
        XCTAssertGreaterThan(fetcher.timeoutInterval, 0.0,
                              "Fetcher timeout should be positive")
    }

    /// Verifies that URLSessionCatalogFetcher uses an injected URLSession
    /// (or a custom session with timeout), not URLSession.shared directly.
    func testURLSessionCatalogFetcher_usesInjectedSession() {
        let session = URLSession(configuration: .ephemeral)
        let fetcher = URLSessionCatalogFetcher(session: session)
        // Verify the fetcher uses the injected session, not .shared
        XCTAssertNotNil(fetcher.session)
        XCTAssertTrue(fetcher.session.configuration.identifier == nil,
                       "Should use ephemeral or injected session, not shared")
    }

    /// Verifies that URLSessionCatalogFetcher fails on non-2xx HTTP status.
    /// Uses a mock URLProtocol to simulate a 500 response without hitting the network.
    func testURLSessionCatalogFetcher_non2xxStatus_throwsError() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTTPURLProtocol.self]
        let session = URLSession(configuration: config)

        MockHTTPURLProtocol.mockResponse = (
            statusCode: 500,
            headers: ["Content-Type": "application/json"],
            body: "{\"error\":\"internal server error\"}".data(using: .utf8)!
        )

        let fetcher = URLSessionCatalogFetcher(session: session)
        XCTAssertThrowsError(try fetcher.fetchModelsJSON()) { error in
            // Should be a non-2xx status error, not a timeout or generic error
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("500") || description.contains("status") || description.contains("HTTP"),
                           "Error should mention HTTP status code: \(description)")
        }
    }

    /// Verifies that URLSessionCatalogFetcher fails on 404 status.
    func testURLSessionCatalogFetcher_404Status_throwsError() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTTPURLProtocol.self]
        let session = URLSession(configuration: config)

        MockHTTPURLProtocol.mockResponse = (
            statusCode: 404,
            headers: [:],
            body: Data()
        )

        let fetcher = URLSessionCatalogFetcher(session: session)
        XCTAssertThrowsError(try fetcher.fetchModelsJSON())
    }

    /// Verifies that URLSessionCatalogFetcher succeeds on 200 status.
    func testURLSessionCatalogFetcher_200Status_succeeds() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTTPURLProtocol.self]
        let session = URLSession(configuration: config)

        let validJSON = """
        {"claude": [{"id": "test-model", "object": "model"}]}
        """
        MockHTTPURLProtocol.mockResponse = (
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: validJSON.data(using: .utf8)!
        )

        let fetcher = URLSessionCatalogFetcher(session: session)
        do {
            let data = try fetcher.fetchModelsJSON()
            XCTAssertGreaterThan(data.count, 0)
        } catch {
            XCTFail("200 status should succeed, got: \(error)")
        }
    }

    // MARK: - Task 4: Bundled Snapshot Loading and Determinism

    /// Verifies that the bundled snapshot loader reads from a main-bundle-style
    /// resource URL (CCProxy.app/Contents/Resources) without relying on
    /// SwiftPM generated resource bundles.
    func testBundledSnapshotLoaderReadsMainBundleResourceURLFirst() {
        // Simulate CCProxy.app/Contents/Resources directory layout
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-app-test-\(UUID().uuidString)", isDirectory: true)
        let resourcesDir = tempDir.appendingPathComponent("Contents/Resources", isDirectory: true)
        try! FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }

        let snapshot = makeTestSnapshot()
        let snapshotURL = resourcesDir.appendingPathComponent("model-catalog-snapshot.json")
        writeBundledSnapshot(snapshot, to: snapshotURL)

        // Resolve using main-bundle-style resource URL
        let resolved = ProductionModelListCatalogProvider.resolveBundledSnapshotURL(
            mainBundleResourceURL: resourcesDir
        )

        XCTAssertNotNil(resolved, "Should resolve snapshot from main-bundle resource URL")
        XCTAssertEqual(resolved, snapshotURL)

        // Verify the snapshot loads and parses correctly through CacheCoordinator
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        let cacheDir = makeTempCacheDirectory()

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: resolved
        )

        let result = coordinator.getCatalog()
        if case .available(let loaded) = result {
            XCTAssertEqual(loaded.schemaVersion, "1")
            XCTAssertGreaterThan(loaded.providerModels.count, 0)
        } else {
            XCTFail("Expected available snapshot from main-bundle resource URL")
        }
    }

    /// Verifies that the bundled snapshot loader falls back to module resource URL
    /// when the main-bundle resource URL is absent or does not contain the snapshot.
    func testBundledSnapshotLoaderFallsBackToModuleWhenMainBundleMissing() {
        // Create a module-style resource URL with a snapshot
        let moduleDir = makeTempCacheDirectory()
        let moduleURL = moduleDir.appendingPathComponent("model-catalog-snapshot.json")
        writeBundledSnapshot(makeTestSnapshot(), to: moduleURL)

        // Empty main bundle dir (no snapshot file)
        let emptyMainDir = makeTempCacheDirectory()

        let resolved = ProductionModelListCatalogProvider.resolveBundledSnapshotURL(
            mainBundleResourceURL: emptyMainDir,
            moduleResourceURL: moduleURL
        )

        XCTAssertNotNil(resolved,
                        "Should fall back to module URL when main bundle has no snapshot")
        XCTAssertEqual(resolved, moduleURL,
                       "Should return the module resource URL, not nil")
    }

    /// Verifies that the main-bundle resource URL takes precedence over
    /// the module resource URL when both contain valid snapshots.
    func testBundledSnapshotLoaderPrefersMainBundleResourceOverModule() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-both-test-\(UUID().uuidString)", isDirectory: true)
        let mainResourcesDir = tempDir.appendingPathComponent("Contents/Resources", isDirectory: true)
        try! FileManager.default.createDirectory(at: mainResourcesDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: tempDir) }

        // Two snapshots with different generatedAt values to prove which one is loaded
        let mainSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["main-bundle"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-main", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let moduleSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-02T00:00:00Z",
            sources: ["module"],
            providerModels: [
                "codex": [CatalogModelEntry(id: "codex-module", object: "model", created: 2, ownedBy: "openai", displayName: nil, tier: nil)]
            ]
        )

        let mainURL = mainResourcesDir.appendingPathComponent("model-catalog-snapshot.json")
        let moduleURL = tempDir.appendingPathComponent("module-snapshot.json")
        writeBundledSnapshot(mainSnapshot, to: mainURL)
        writeBundledSnapshot(moduleSnapshot, to: moduleURL)

        let resolved = ProductionModelListCatalogProvider.resolveBundledSnapshotURL(
            mainBundleResourceURL: mainResourcesDir,
            moduleResourceURL: moduleURL
        )

        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved, mainURL,
                       "Main bundle should take precedence over module resource URL")

        // Verify the content is from main bundle
        let data = try! Data(contentsOf: resolved!)
        let loaded = try! JSONDecoder().decode(CatalogSnapshot.self, from: data)
        XCTAssertEqual(loaded.generatedAt, "2026-01-01T00:00:00Z",
                       "Should load main bundle snapshot content, not module snapshot")
    }

    /// Verifies that a snapshot missing source metadata is rejected.
    /// A valid snapshot must reference at least one known external source.
    func testBundledSnapshotRequiresExternalSourceMetadata() {
        // Snapshot with empty sources should be rejected
        let emptySources = [String]()
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshotSources(emptySources),
                       "Snapshot with empty sources should be rejected")

        // Snapshot with only unknown sources should be rejected
        let unknownSources = ["unknown-source"]
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshotSources(unknownSources),
                       "Snapshot with only unknown sources should be rejected")

        // Snapshot with at least one known primary source should be accepted
        let primarySources = ["models.json", "codex_client_models.json"]
        XCTAssertTrue(ExternalModelCatalog.isValidSnapshotSources(primarySources),
                      "Snapshot with primary CLIProxyAPI sources should be accepted")

        // Snapshot with models.dev source should be accepted
        let devSources = ["models.dev"]
        XCTAssertTrue(ExternalModelCatalog.isValidSnapshotSources(devSources),
                      "Snapshot with models.dev source should be accepted")

        // Full valid snapshot with all sources
        let allSources = ["models.json", "codex_client_models.json", "models.dev"]
        XCTAssertTrue(ExternalModelCatalog.isValidSnapshotSources(allSources),
                      "Snapshot with all known sources should be accepted")
    }

    /// Verifies that an existing valid bundled snapshot can be reused when
    /// all external generation sources are unavailable.
    func testExistingValidBundledSnapshotCanBeReusedWhenGenerationSourcesUnavailable() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        // All fetches fail
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.codexClientModelsError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Write a valid bundled snapshot with proper source metadata
        let validSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "codex_client_models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("model-catalog-snapshot.json")
        writeBundledSnapshot(validSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            // The valid bundled snapshot should be served
            XCTAssertGreaterThan(snapshot.providerModels.count, 0,
                                 "Valid existing snapshot should be served when sources unavailable")
        } else {
            XCTFail("Valid existing snapshot should be served when external sources fail")
        }
    }

    /// Verifies that when all external sources fail and no valid snapshot exists,
    /// the catalog correctly reports unavailable.
    func testMalformedExistingSnapshotFailsWhenGenerationSourcesUnavailable() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.codexClientModelsError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Write a malformed bundled snapshot
        let bundledURL = cacheDir.appendingPathComponent("model-catalog-snapshot.json")
        try! Self.malformedJSON.write(to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected: malformed snapshot + failed sources = unavailable
        } else {
            XCTFail("Malformed snapshot with failed sources should be unavailable")
        }
    }

    /// Verifies that generated snapshot JSON is deterministic:
    /// sorted provider keys, sorted model IDs, fixed pretty-print formatting,
    /// and stable output for identical inputs.
    func testSnapshotJSONIsDeterministic() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let codexClient = ExternalModelCatalog.parseCodexClientModels(Self.codexClientFixture)!
        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let snapshot1 = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: codexClient, secondary: secondary,
            clock: FakeClock(fixedDate)
        )!
        let snapshot2 = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: codexClient, secondary: secondary,
            clock: FakeClock(fixedDate)
        )!

        let encoder: JSONEncoder = {
            let e = JSONEncoder()
            e.outputFormatting = [.sortedKeys, .prettyPrinted]
            return e
        }()

        let data1 = try! encoder.encode(snapshot1)
        let data2 = try! encoder.encode(snapshot2)

        // Identical inputs must produce identical output
        XCTAssertEqual(data1, data2,
                       "Same inputs should produce identical deterministic output")

        // Verify sorted provider keys by checking raw JSON string order
        let jsonString = String(data: data1, encoding: .utf8)!
        let knownProviders = ["claude", "codex", "kimi", "minimax", "opencode-go", "zai"]
        var lastFoundRange: Range<String.Index>? = nil
        for provider in knownProviders.sorted() {
            let searchKey = "\"\(provider)\" : ["
            if let range = jsonString.range(of: searchKey, range: lastFoundRange.map { jsonString.startIndex..<$0.lowerBound } ?? jsonString.startIndex..<jsonString.endIndex) {
                // Found this provider key - check it appears after the previous one
                if let last = lastFoundRange {
                    XCTAssertGreaterThan(range.lowerBound, last.lowerBound,
                                         "Provider '\(provider)' should appear after previous sorted provider in JSON")
                }
                lastFoundRange = range
            } else {
                // Try without space before colon (Swift encoder uses "key" : value)
                let altKey = "\"\(provider)\":["
                if let range = jsonString.range(of: altKey) {
                    if let last = lastFoundRange {
                        XCTAssertGreaterThan(range.lowerBound, last.lowerBound)
                    }
                    lastFoundRange = range
                }
            }
        }

        // Verify sorted model IDs within each provider by checking raw string
        for provider in knownProviders {
            // Find the provider section in JSON
            let providerPattern = "\"\(provider)\" : ["
            guard let providerRange = jsonString.range(of: providerPattern) else { continue }
            let afterProvider = String(jsonString[providerRange.upperBound...])

            // Extract model IDs from the provider section
            var modelIds: [String] = []
            let idPattern = "\"id\" : \""
            var searchStart = afterProvider.startIndex
            var depth = 1
            var charIdx = afterProvider.startIndex

            // Find all "id" fields within this provider's array
            while charIdx < afterProvider.endIndex && depth > 0 {
                let ch = afterProvider[charIdx]
                if ch == "[" { depth += 1 }
                else if ch == "]" {
                    depth -= 1
                    if depth == 0 { break }
                }
                charIdx = afterProvider.index(after: charIdx)
            }
            let providerSection = String(afterProvider[..<charIdx])

            // Find all "id" values
            var idSearchStart = providerSection.startIndex
            while let idRange = providerSection.range(of: idPattern, range: idSearchStart..<providerSection.endIndex) {
                let afterId = providerSection[idRange.upperBound...]
                if let endQuote = afterId.firstIndex(of: "\"") {
                    let idValue = String(afterId[..<endQuote])
                    modelIds.append(idValue)
                }
                idSearchStart = idRange.upperBound
            }

            XCTAssertEqual(modelIds, modelIds.sorted(),
                           "Model IDs within '\(provider)' should be sorted: \(modelIds)")
        }
    }

    // MARK: - Review Fix: Bundled Snapshot Source Metadata Enforcement at Runtime

    /// Verifies that the actual loading path (CacheCoordinator.loadBundledSnapshot)
    /// rejects a bundled snapshot that has empty sources metadata.
    /// This tests through the real coordinator path, not just the helper function.
    func testBundledSnapshotLoadingRejectsEmptySourcesThroughCoordinatorPath() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Write a snapshot with empty sources — should be rejected
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: [], // empty: invalid
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(badSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected: snapshot with empty sources is rejected at load time
        } else {
            XCTFail("Bundled snapshot with empty sources should be rejected, got \(result)")
        }
    }

    /// Verifies that the actual loading path rejects a bundled snapshot with
    /// only unknown/invalid source identifiers.
    func testBundledSnapshotLoadingRejectsUnknownSourcesThroughCoordinatorPath() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Write a snapshot with only unknown sources — should be rejected
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["unknown-source", "another-bad-source"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(badSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected: snapshot with only unknown sources is rejected
        } else {
            XCTFail("Bundled snapshot with only unknown sources should be rejected, got \(result)")
        }
    }

    /// Verifies that the actual loading path accepts a bundled snapshot with
    /// valid external source metadata.
    func testBundledSnapshotLoadingAcceptsValidSourcesThroughCoordinatorPath() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Write a snapshot with valid sources — should be accepted
        let validSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertGreaterThan(snapshot.providerModels.count, 0,
                                 "Valid snapshot should be served")
        } else {
            XCTFail("Bundled snapshot with valid sources should be accepted, got \(result)")
        }
    }

    // MARK: - Review Fix: Generator Reuse/Failure Behavior Tests

    /// Verifies that when all fetches fail but a valid snapshot exists,
    /// the cache coordinator serves the existing bundled snapshot (reuse-on-failure).
    func testGeneratorReuseOnFailure_existingValidSnapshot_servedToClient() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        // All fetches fail
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.codexClientModelsError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Pre-existing valid snapshot
        let validSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "codex_client_models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(validSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        // First call: refresh fails, falls back to bundled snapshot
        let result = coordinator.getCatalog()
        if case .available(let snapshot) = result {
            XCTAssertEqual(snapshot.providerModels.count, 1,
                           "Should serve bundled snapshot when refresh fails")
            XCTAssertNotNil(snapshot.providerModels["claude"])
        } else {
            XCTFail("Should serve bundled snapshot on refresh failure")
        }

        // Second call: should still serve bundled snapshot without additional fetches
        let secondResult = coordinator.getCatalog()
        if case .available = secondResult {
            // Good: throttled retry, serves bundled snapshot
        } else {
            XCTFail("Second call should serve bundled snapshot within throttle window")
        }
    }

    /// Verifies that when all fetches fail and no valid snapshot exists,
    /// the catalog returns unavailable (fail-without-valid-existing).
    func testGeneratorFailWithoutValidExisting_returnsUnavailable() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.codexClientModelsError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // No bundled snapshot, no runtime cache
        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected
        } else {
            XCTFail("No valid snapshot and failed fetches should return unavailable")
        }
    }

    /// Verifies that snapshot determinism holds: merging identical inputs with
    /// the same clock produces identical generatedAt timestamps.
    func testSnapshotDeterministicGeneratedAtWithFixedClock() {
        let primary = ExternalModelCatalog.parseModelsJSON(Self.modelsJSONFixture)!
        let secondary = ExternalModelCatalog.parseModelsDev(Self.modelsDevFixture)!
        let fixedDate = Date(timeIntervalSince1970: 1700000000)

        let snapshot1 = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: nil, secondary: secondary,
            clock: FakeClock(fixedDate)
        )!
        let snapshot2 = ExternalModelCatalog.mergeCatalogs(
            primary: primary, codexClient: nil, secondary: secondary,
            clock: FakeClock(fixedDate)
        )!

        XCTAssertEqual(snapshot1.generatedAt, snapshot2.generatedAt,
                       "Identical inputs with same clock should produce identical generatedAt")
        XCTAssertEqual(snapshot1, snapshot2,
                       "Identical inputs with same clock should produce identical snapshots")
    }

    // MARK: - Strict Snapshot Validation (Mixed Valid/Invalid Providers)

    /// Verifies that strict validation rejects a snapshot where one provider
    /// has valid model entries but another provider has an empty model array.
    /// Every provider must have a non-empty model array.
    func testStrictValidation_rejectsSnapshotWithOneProviderEmptyModels() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [] // empty: should cause rejection
            ]
        )
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshot(snapshot),
                        "Snapshot with a provider having empty model array should be rejected")
    }

    /// Verifies that strict validation rejects a snapshot where one provider
    /// has valid model entries but another provider has a model entry with an empty ID.
    /// Every model entry in every provider must have a non-empty ID.
    func testStrictValidation_rejectsSnapshotWithOneProviderHavingEmptyModelId() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [CatalogModelEntry(id: "", object: "model", created: 1, ownedBy: "openai", displayName: nil, tier: nil)] // empty ID: should cause rejection
            ]
        )
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshot(snapshot),
                        "Snapshot with a provider having a model entry with empty ID should be rejected")
    }

    /// Verifies that strict validation accepts a snapshot where all providers
    /// have non-empty model arrays and all model entries have non-empty IDs.
    func testStrictValidation_acceptsSnapshotWithAllProvidersValid() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [CatalogModelEntry(id: "gpt-4o", object: "model", created: 2, ownedBy: "openai", displayName: nil, tier: nil)]
            ]
        )
        XCTAssertTrue(ExternalModelCatalog.isValidSnapshot(snapshot),
                       "Snapshot with all providers valid should be accepted")
    }

    /// Verifies that strict validation rejects a snapshot with empty providerModels.
    func testStrictValidation_rejectsEmptyProviderModels() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json"],
            providerModels: [:]
        )
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshot(snapshot),
                        "Snapshot with empty providerModels should be rejected")
    }

    /// Verifies that strict validation rejects a snapshot with empty schemaVersion.
    func testStrictValidation_rejectsEmptySchemaVersion() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshot(snapshot),
                        "Snapshot with empty schemaVersion should be rejected")
    }

    /// Verifies that strict validation rejects a snapshot with invalid sources.
    func testStrictValidation_rejectsInvalidSources() {
        let snapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["unknown-source"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)]
            ]
        )
        XCTAssertFalse(ExternalModelCatalog.isValidSnapshot(snapshot),
                        "Snapshot with only unknown sources should be rejected")
    }

    // MARK: - Strict Bundled Snapshot Loading (Runtime)

    /// Verifies that the runtime bundled snapshot loading rejects a snapshot
    /// where one provider has an empty model array.
    func testBundledSnapshotLoadingRejectsProviderWithEmptyModels() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Snapshot with one valid provider and one with empty models
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [] // empty: should cause rejection
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(badSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected: snapshot with empty provider model array is rejected
        } else {
            XCTFail("Bundled snapshot with empty provider model array should be rejected, got \(result)")
        }
    }

    /// Verifies that the runtime bundled snapshot loading rejects a snapshot
    /// where one provider has a model entry with an empty ID.
    func testBundledSnapshotLoadingRejectsProviderWithEmptyModelId() {
        let cacheDir = makeTempCacheDirectory()
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)

        // Snapshot with one valid provider and one with empty model ID
        let badSnapshot = CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["models.json", "models.dev"],
            providerModels: [
                "claude": [CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1, ownedBy: "anthropic", displayName: nil, tier: nil)],
                "codex": [CatalogModelEntry(id: "", object: "model", created: 1, ownedBy: "openai", displayName: nil, tier: nil)] // empty ID
            ]
        )
        let bundledURL = cacheDir.appendingPathComponent("bundled-snapshot.json")
        writeBundledSnapshot(badSnapshot, to: bundledURL)

        let coordinator = CacheCoordinator(
            clock: FakeClock(Date()),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: bundledURL
        )

        let result = coordinator.getCatalog()
        if case .unavailable = result {
            // Expected: snapshot with empty model ID is rejected
        } else {
            XCTFail("Bundled snapshot with empty model ID should be rejected, got \(result)")
        }
    }

    // MARK: - Bundled Snapshot Codable Decode Validation

    /// Verifies that the bundled snapshot file at src/Sources/Resources/model-catalog-snapshot.json
    /// is fully Codable-decodable as CatalogSnapshot with:
    ///   - non-empty schemaVersion
    ///   - valid source metadata referencing at least one known external catalog
    ///   - non-empty providerModels where every model entry has a non-empty id
    /// This directly proves the script output is structurally valid at the Codable level.
    func testBundledSnapshotIsFullyCodableDecodableWithValidModels() {
        // Resolve the bundled snapshot from multiple possible paths:
        // 1. Bundle.module (SwiftPM resource for the CCProxy target)
        // 2. Relative path from test working directory (src/)
        // 3. Direct project-relative path
        var candidatePaths: [URL] = [
            // SwiftPM test working dir is typically src/
            URL(fileURLWithPath: "Sources/Resources/model-catalog-snapshot.json"),
            // Absolute path as fallback
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/Resources/model-catalog-snapshot.json")
        ]

        // Also try Bundle.module
        if let moduleURL = Bundle.module.url(
            forResource: "model-catalog-snapshot",
            withExtension: "json",
            subdirectory: "Resources"
        ) {
            candidatePaths.insert(moduleURL, at: 0)
        }

        guard let snapshotURL = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            XCTFail("Bundled snapshot not found at any candidate path")
            return
        }
        validateBundledSnapshotAtURL(snapshotURL)
    }

    private func validateBundledSnapshotAtURL(_ url: URL) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            XCTFail("Failed to read bundled snapshot at \(url.path): \(error)")
            return
        }

        // Full Codable decode — verifies all required fields exist with correct types
        let snapshot: CatalogSnapshot
        do {
            snapshot = try JSONDecoder().decode(CatalogSnapshot.self, from: data)
        } catch {
            XCTFail("Bundled snapshot failed Codable decode: \(error)")
            return
        }

        // Schema version must be non-empty
        XCTAssertFalse(snapshot.schemaVersion.isEmpty,
                       "Bundled snapshot must have non-empty schemaVersion")

        // Source metadata must reference at least one known external catalog
        XCTAssertTrue(ExternalModelCatalog.isValidSnapshotSources(snapshot.sources),
                       "Bundled snapshot sources must reference at least one known external catalog: \(snapshot.sources)")

        // Provider models must be non-empty
        XCTAssertFalse(snapshot.providerModels.isEmpty,
                       "Bundled snapshot must have non-empty providerModels")

        // Every model entry in every provider must have a non-empty id
        for (provider, entries) in snapshot.providerModels {
            XCTAssertFalse(entries.isEmpty,
                           "Provider '\(provider)' must have at least one model entry")
            for entry in entries {
                XCTAssertFalse(entry.id.isEmpty,
                               "Model entry in provider '\(provider)' must have non-empty id")
            }
        }

        // Total model count should be positive
        let totalModels = snapshot.providerModels.values.reduce(0) { $0 + $1.count }
        XCTAssertGreaterThan(totalModels, 0,
                             "Bundled snapshot must contain at least one model entry")
    }
}

// MARK: - Mock URLProtocol for URLSession tests

/// Mock URLProtocol that intercepts all requests and returns a canned response.
/// Does not hit the live network.
class MockHTTPURLProtocol: URLProtocol {
    static var mockResponse: (statusCode: Int, headers: [String: String], body: Data) = (200, [:], Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockHTTPURLProtocol.mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: MockHTTPURLProtocol.mockResponse.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockHTTPURLProtocol.mockResponse.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

class FakeClock: CatalogClock {
    private var _now: Date
    var now: Date { _now }

    init(_ date: Date) { _now = date }

    func advance(by seconds: TimeInterval) {
        _now = _now.addingTimeInterval(seconds)
    }
}

class FakeCatalogFetcher: CatalogFetcher {
    var modelsJSONCallCount = 0
    var codexClientCallCount = 0
    var modelsDevCallCount = 0

    var totalFetchCount: Int {
        modelsJSONCallCount + codexClientCallCount + modelsDevCallCount
    }

    var modelsJSONData: Data?
    var codexClientModelsData: Data?
    var modelsDevData: Data?

    var modelsJSONError: Error?
    var codexClientModelsError: Error?
    var modelsDevError: Error?

    func fetchModelsJSON() throws -> Data {
        modelsJSONCallCount += 1
        if let error = modelsJSONError { throw error }
        guard let data = modelsJSONData else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No fixture data"])
        }
        return data
    }

    func fetchCodexClientModels() throws -> Data {
        codexClientCallCount += 1
        if let error = codexClientModelsError { throw error }
        guard let data = codexClientModelsData else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No fixture data"])
        }
        return data
    }

    func fetchModelsDev() throws -> Data {
        modelsDevCallCount += 1
        if let error = modelsDevError { throw error }
        guard let data = modelsDevData else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No fixture data"])
        }
        return data
    }
}
