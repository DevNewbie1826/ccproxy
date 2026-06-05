import Foundation

// MARK: - Provider Mappings

/// Enum namespace for external model catalog parsing, merging, filtering, and rendering.
enum ExternalModelCatalog {

    /// CLIProxyAPI primary provider key → CCProxy provider ID normalization.
    /// Only keys present in this map are emitted as CCProxy providers.
    static let primaryProviderMapping: [String: String] = [
        "claude": "claude",
        "codex-free": "codex",
        "codex-team": "codex",
        "codex-plus": "codex",
        "codex-pro": "codex",
        "kimi": "kimi"
    ]

    /// CCProxy provider ID → models.dev provider key (reverse lookup for secondary source).
    static let secondaryProviderMapping: [String: String] = [
        "claude": "anthropic",
        "codex": "openai",
        "zai": "zai-coding-plan",
        "minimax": "minimax-coding-plan",
        "kimi": "moonshotai",
        "opencode-go": "opencode-go"
    ]

    // MARK: - Config Model Name Extraction

    /// Extracts model name arrays keyed by CCProxy provider ID from a snapshot,
    /// suitable for config generation. For providers using prefix + force-model-prefix
    /// (like opencode-go), model IDs are stripped of their provider prefix because
    /// the generated config block adds the prefix at runtime.
    static func extractConfigModelNames(from snapshot: CatalogSnapshot) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (provider, entries) in snapshot.providerModels {
            let modelNames = entries.map { entry -> String in
                if entry.id.hasPrefix("\(provider)/") {
                    return String(entry.id.dropFirst("\(provider)/".count))
                }
                return entry.id
            }
            result[provider] = modelNames
        }
        return result
    }

    // MARK: - Snapshot Validation

    /// Known external source identifiers that indicate a snapshot was generated
    /// from real external data rather than hand-written.
    private static let knownSourceIdentifiers: Set<String> = [
        "models.json",
        "codex_client_models.json",
        "models.dev"
    ]

    /// Validates that a snapshot's source metadata references at least one
    /// known external catalog source. Rejects empty or unknown-only sources.
    static func isValidSnapshotSources(_ sources: [String]) -> Bool {
        guard !sources.isEmpty else { return false }
        return sources.contains { knownSourceIdentifiers.contains($0) }
    }

    /// Strict validation for a complete snapshot: requires non-empty schemaVersion,
    /// valid external source metadata, non-empty providerModels, every provider
    /// has a non-empty model array, and every model entry has a non-empty ID.
    /// Rejects any provider with an empty array or any model with an empty ID.
    static func isValidSnapshot(_ snapshot: CatalogSnapshot) -> Bool {
        // Non-empty schemaVersion
        guard !snapshot.schemaVersion.isEmpty else { return false }

        // Valid external source metadata
        guard isValidSnapshotSources(snapshot.sources) else { return false }

        // Non-empty providerModels
        guard !snapshot.providerModels.isEmpty else { return false }

        // Every provider must have a non-empty model array
        // and every model entry must have a non-empty ID
        for (_, entries) in snapshot.providerModels {
            guard !entries.isEmpty else { return false }
            for entry in entries {
                guard !entry.id.isEmpty else { return false }
            }
        }

        return true
    }

    // MARK: - Parsing

    /// Parse CLIProxyAPI models.json: top-level provider-key object with array values.
    /// Each descriptor must contain a string `id`. Unknown fields are ignored.
    /// Returns nil for malformed JSON or zero valid model entries.
    static func parseModelsJSON(_ data: Data) -> ParsedSource? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var providerModels: [String: [CatalogModel]] = [:]
        var totalValidModels = 0

        for sourceKey in json.keys.sorted() {
            guard let value = json[sourceKey],
                  let descriptors = value as? [[String: Any]] else { continue }

            // Determine CCProxy provider and tier from source key
            let ccproxyProvider: String
            let tier: String?

            if let mapped = primaryProviderMapping[sourceKey] {
                ccproxyProvider = mapped
                // Derive tier from the source key after the prefix
                if sourceKey.hasPrefix("codex-") {
                    tier = String(sourceKey.dropFirst("codex-".count))
                } else {
                    tier = nil
                }
            } else {
                // Unmapped key: parse but don't normalize to a CCProxy provider
                ccproxyProvider = sourceKey
                tier = nil
            }

            var models: [CatalogModel] = []
            for descriptor in descriptors {
                guard let id = descriptor["id"] as? String, !id.isEmpty else { continue }

                let object = descriptor["object"] as? String ?? "model"
                let created = descriptor["created"] as? Int ?? 0
                let ownedBy = descriptor["owned_by"] as? String
                    ?? descriptor["ownedBy"] as? String
                    ?? ccproxyProvider
                let displayName = descriptor["display_name"] as? String
                    ?? descriptor["displayName"] as? String

                let model = CatalogModel(
                    id: id,
                    object: object,
                    created: created,
                    ownedBy: ownedBy,
                    displayName: displayName,
                    tier: tier,
                    sourceProvenance: "models.json:\(sourceKey)",
                    supplementalMetadata: [:]
                )
                models.append(model)
                totalValidModels += 1
            }

            if !models.isEmpty {
                models.sort { $0.id < $1.id }
                providerModels[ccproxyProvider, default: []].append(contentsOf: models)
            }
        }

        guard totalValidModels > 0 else { return nil }
        return ParsedSource(providerModels: providerModels)
    }

    /// Parse CLIProxyAPI codex_client_models.json: object with `models` array.
    /// `slug` becomes the model ID. All models go under "codex" provider.
    /// Returns nil for malformed JSON or zero valid model entries.
    static func parseCodexClientModels(_ data: Data) -> ParsedSource? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            return nil
        }

        var codexModels: [CatalogModel] = []

        for descriptor in modelsArray {
            guard let slug = descriptor["slug"] as? String, !slug.isEmpty else { continue }

            let displayName = descriptor["display_name"] as? String
                ?? descriptor["displayName"] as? String
            let ownedBy = descriptor["owned_by"] as? String
                ?? descriptor["ownedBy"] as? String
                ?? "openai"

            // Capture supplemental metadata from descriptor fields beyond known ones
            let knownKeys: Set<String> = ["slug", "display_name", "displayName", "owned_by", "ownedBy"]
            var supplemental: [String: String] = [:]
            for (key, value) in descriptor {
                if knownKeys.contains(key) { continue }
                if let strValue = value as? String {
                    supplemental[key] = strValue
                } else {
                    supplemental[key] = String(describing: value)
                }
            }

            let model = CatalogModel(
                id: slug,
                object: "model",
                created: 0,
                ownedBy: ownedBy,
                displayName: displayName,
                tier: nil,
                sourceProvenance: "codex_client_models.json",
                supplementalMetadata: supplemental
            )
            codexModels.append(model)
        }

        guard !codexModels.isEmpty else { return nil }

        codexModels.sort { $0.id < $1.id }
        return ParsedSource(providerModels: ["codex": codexModels])
    }

    /// Parse models.dev api.json: top-level provider-key object with nested `models` objects.
    /// Model IDs come from the nested keys. Only mapped providers are included.
    /// Returns nil for malformed JSON or zero valid model entries.
    static func parseModelsDev(_ data: Data) -> ParsedSource? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Build reverse mapping: models.dev key → CCProxy provider
        var devToCCProxy: [String: String] = [:]
        for (ccproxy, devKey) in secondaryProviderMapping {
            devToCCProxy[devKey] = ccproxy
        }

        var providerModels: [String: [CatalogModel]] = [:]
        var totalValidModels = 0

        for devProviderKey in json.keys.sorted() {
            guard let ccproxyProvider = devToCCProxy[devProviderKey],
                  let providerValue = json[devProviderKey] as? [String: Any],
                  let modelsObj = providerValue["models"] as? [String: Any] else {
                continue
            }

            var models: [CatalogModel] = []
            for modelKey in modelsObj.keys.sorted() {
                let modelValue = modelsObj[modelKey]
                let descriptor = modelValue as? [String: Any] ?? [:]

                let id = descriptor["id"] as? String
                    ?? descriptor["slug"] as? String
                    ?? modelKey
                guard !id.isEmpty else { continue }

                let ownedBy = descriptor["owned_by"] as? String
                    ?? descriptor["ownedBy"] as? String
                    ?? ccproxyProvider
                let displayName = descriptor["display_name"] as? String
                    ?? descriptor["displayName"] as? String
                let created = descriptor["created"] as? Int ?? 0

                let model = CatalogModel(
                    id: id,
                    object: "model",
                    created: created,
                    ownedBy: ownedBy,
                    displayName: displayName,
                    tier: nil,
                    sourceProvenance: "models.dev:\(devProviderKey)",
                    supplementalMetadata: [:]
                )
                models.append(model)
                totalValidModels += 1
            }

            if !models.isEmpty {
                models.sort { $0.id < $1.id }
                providerModels[ccproxyProvider, default: []].append(contentsOf: models)
            }
        }

        guard totalValidModels > 0 else { return nil }
        return ParsedSource(providerModels: providerModels)
    }

    // MARK: - Merge

    /// Merge catalog sources with primary-first precedence:
    /// 1. Primary entries are inserted first after provider-key normalization.
    /// 2. codex_client_models.json supplements Codex models by slug.
    /// 3. Secondary (models.dev) fills only missing mapped providers.
    /// Returns nil when all sources are nil or produce an empty result.
    static func mergeCatalogs(
        primary: ParsedSource?,
        codexClient: ParsedSource?,
        secondary: ParsedSource?,
        clock: any CatalogClock
    ) -> CatalogSnapshot? {
        var mergedModels: [String: [CatalogModelEntry]] = [:]

        // 1. Insert primary models
        if let primary = primary {
            let knownProviders = Set(primaryProviderMapping.values)
            for provider in primary.providerModels.keys.sorted() {
                guard knownProviders.contains(provider) else { continue }
                let models = primary.providerModels[provider]!
                var entries = models.map { $0.toEntry() }
                // Sort by (id, tier) for deterministic dedup: lower tier order wins
                entries.sort { a, b in
                    if a.id != b.id { return a.id < b.id }
                    return Self.tierOrder(a.tier) < Self.tierOrder(b.tier)
                }
                entries = deduplicate(entries)
                mergedModels[provider] = entries
            }
        }

        // 2. Supplement codex models with codex_client metadata by slug
        if let codexClient = codexClient {
            let codexClientModels = codexClient.providerModels["codex"] ?? []
            if var codexEntries = mergedModels["codex"] {
                for clientModel in codexClientModels {
                    if let idx = codexEntries.firstIndex(where: { $0.id == clientModel.id }) {
                        // Supplement with display name and supplemental metadata
                        codexEntries[idx] = CatalogModelEntry(
                            id: codexEntries[idx].id,
                            object: codexEntries[idx].object,
                            created: codexEntries[idx].created,
                            ownedBy: codexEntries[idx].ownedBy,
                            displayName: clientModel.displayName ?? codexEntries[idx].displayName,
                            tier: codexEntries[idx].tier,
                            supplementalMetadata: clientModel.supplementalMetadata
                        )
                    }
                }
                mergedModels["codex"] = codexEntries
            } else {
                // No primary codex, but codex_client models still go under "codex"
                let entries = deduplicate(codexClientModels.map { $0.toEntry() })
                if !entries.isEmpty {
                    mergedModels["codex"] = entries
                }
            }
        }

        // 3. Fill missing providers/models from secondary
        //    Primary descriptors always win; secondary fills only missing coverage.
        if let secondary = secondary {
            for provider in secondary.providerModels.keys.sorted() {
                let models = secondary.providerModels[provider]!
                if mergedModels[provider] == nil {
                    // No primary coverage at all: add all secondary models
                    let entries = deduplicate(models.map { $0.toEntry() })
                    if !entries.isEmpty {
                        mergedModels[provider] = entries
                    }
                } else {
                    // Partial coverage: fill in only missing individual model IDs
                    let existingIds = Set(mergedModels[provider]!.map { $0.id })
                    let newEntries = models
                        .map { $0.toEntry() }
                        .filter { !existingIds.contains($0.id) }
                    if !newEntries.isEmpty {
                        mergedModels[provider]!.append(contentsOf: newEntries)
                    }
                }
            }
        }

        guard !mergedModels.isEmpty else { return nil }

        // Sort all model entries by ID within each provider for deterministic output
        for provider in mergedModels.keys {
            mergedModels[provider]?.sort { $0.id < $1.id }
        }

        let timestamp = clock.now
        return CatalogSnapshot(
            schemaVersion: "1",
            generatedAt: ISO8601DateFormatter().string(from: timestamp),
            sources: ["models.json", "codex_client_models.json", "models.dev"],
            providerModels: mergedModels
        )
    }

    // MARK: - Filter

    /// Filter catalog to only include models for connected providers.
    /// Provider-qualifies each model ID: "{provider}/{model_id}".
    /// Never infers connectivity from catalog presence.
    static func filterCatalog(
        snapshot: CatalogSnapshot,
        connectedProviders: Set<String>
    ) -> [CatalogModel] {
        var result: [CatalogModel] = []

        for provider in connectedProviders.sorted() {
            guard let entries = snapshot.providerModels[provider] else { continue }
            for entry in entries.sorted(by: { $0.id < $1.id }) {
                // Strip provider prefix from entry.id if already present to avoid double-prefix
                let modelId: String
                if entry.id.hasPrefix("\(provider)/") {
                    modelId = String(entry.id.dropFirst("\(provider)/".count))
                } else {
                    modelId = entry.id
                }
                let qualifiedId = "\(provider)/\(modelId)"
                let model = CatalogModel(
                    id: qualifiedId,
                    object: entry.object,
                    created: entry.created,
                    ownedBy: entry.ownedBy,
                    displayName: entry.displayName,
                    tier: entry.tier,
                    sourceProvenance: "catalog",
                    supplementalMetadata: entry.supplementalMetadata
                )
                result.append(model)
            }
        }

        return result
    }

    // MARK: - Render

    /// Render filtered models as OpenAI-style model-list JSON:
    /// `{ "object": "list", "data": [...] }`
    static func renderModelList(models: [CatalogModel]) -> Data {
        var dataEntries: [[String: Any]] = []

        for model in models {
            dataEntries.append([
                "id": model.id,
                "object": model.object,
                "created": model.created,
                "owned_by": model.ownedBy
            ])
        }

        let response: [String: Any] = [
            "object": "list",
            "data": dataEntries
        ]

        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }

    // MARK: - Helpers

    private static func tierOrder(_ tier: String?) -> Int {
        switch tier {
        case "free": return 0
        case "team": return 1
        case "plus": return 2
        case "pro": return 3
        case nil: return -1
        default: return Int.max
        }
    }

    private static func deduplicate(_ entries: [CatalogModelEntry]) -> [CatalogModelEntry] {
        var seen = Set<String>()
        var result: [CatalogModelEntry] = []
        for entry in entries {
            if seen.insert(entry.id).inserted {
                result.append(entry)
            }
        }
        return result
    }
}

// MARK: - Types

struct ParsedSource {
    let providerModels: [String: [CatalogModel]]
}

struct CatalogModel: Equatable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    let displayName: String?
    let tier: String?
    let sourceProvenance: String
    var supplementalMetadata: [String: String]

    func toEntry() -> CatalogModelEntry {
        CatalogModelEntry(
            id: id,
            object: object,
            created: created,
            ownedBy: ownedBy,
            displayName: displayName,
            tier: tier,
            supplementalMetadata: supplementalMetadata
        )
    }
}

struct CatalogModelEntry: Codable, Equatable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    let displayName: String?
    let tier: String?
    let supplementalMetadata: [String: String]

    init(id: String, object: String, created: Int, ownedBy: String,
         displayName: String?, tier: String?,
         supplementalMetadata: [String: String] = [:]) {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
        self.displayName = displayName
        self.tier = tier
        self.supplementalMetadata = supplementalMetadata
    }
}

struct CatalogSnapshot: Codable, Equatable {
    let schemaVersion: String
    let generatedAt: String
    let sources: [String]
    let providerModels: [String: [CatalogModelEntry]]
}

struct CacheMetadata: Codable {
    let cacheWrittenAt: String
    let lastRefreshAttemptAt: String?
    let lastFailure: CacheFailureMetadata?
}

struct CacheFailureMetadata: Codable, Equatable {
    let timestamp: String
    let sourceErrors: [String: String]
}

enum CatalogAvailability {
    case available(CatalogSnapshot)
    case unavailable
}

/// Result type for catalog model-list queries, distinguishing between
/// available catalog (possibly empty connected-provider set) and
/// unavailable catalog (no valid cache/snapshot).
enum CatalogModelsResult: Equatable {
    /// Catalog is available. The models array contains only connected-provider entries.
    /// An empty array means no connected providers — a valid response distinct from unavailable.
    case available([CatalogModel])
    /// Catalog is unavailable (no valid runtime cache, no valid bundled snapshot,
    /// and refresh failed or was throttled). The caller returns an explicit empty
    /// model list to prevent backend model leakage (not a backend pass-through).
    case unavailable
}

// MARK: - Protocols

protocol CatalogClock {
    var now: Date { get }
}

protocol CatalogFetcher {
    func fetchModelsJSON() throws -> Data
    func fetchCodexClientModels() throws -> Data
    func fetchModelsDev() throws -> Data
}

// MARK: - Cache Coordinator

class CacheCoordinator {
    private let clock: CatalogClock
    private let fetcher: CatalogFetcher
    private let cacheDirectory: URL
    private let bundledSnapshotURL: URL?

    private let ttlSeconds: TimeInterval = 6 * 3600   // 6 hours
    private let retryThrottleSeconds: TimeInterval = 15 * 60  // 15 minutes

    /// Serial queue protecting mutable in-memory state from concurrent /v1/models access.
    private let stateQueue = DispatchQueue(label: "com.devnewbie1826.ccproxy.cache-coordinator")

    // In-memory state (accessed only on stateQueue)
    private var _inMemorySnapshot: CatalogSnapshot?
    private var _inMemorySnapshotDate: Date?
    private var _inMemoryLastRefreshAttempt: Date?
    private var _inMemoryFailureMetadata: CacheFailureMetadata?

    init(clock: CatalogClock, fetcher: CatalogFetcher, cacheDirectory: URL, bundledSnapshotURL: URL?) {
        self.clock = clock
        self.fetcher = fetcher
        self.cacheDirectory = cacheDirectory
        self.bundledSnapshotURL = bundledSnapshotURL
    }

    func getCatalog() -> CatalogAvailability {
        return stateQueue.sync {
            _getCatalogUnsafe()
        }
    }

    // MARK: - Private (runs on stateQueue)

    private func _getCatalogUnsafe() -> CatalogAvailability {
        let now = clock.now

        // Check in-memory snapshot first (authoritative current state from refresh).
        // This must be checked before disk cache because a successful refresh always
        // updates _inMemorySnapshot, but the disk cache write may fail silently,
        // leaving stale disk data behind. Prioritizing in-memory ensures fresh data
        // from a successful refresh is never hidden by stale disk cache.
        if let inMemory = _inMemorySnapshot, let memoryDate = _inMemorySnapshotDate {
            let age = now.timeIntervalSince(memoryDate)

            if age < ttlSeconds {
                return .available(inMemory)
            }

            // Stale in-memory: check throttle
            if let lastAttempt = effectiveLastRefreshAttempt(now: now),
               now.timeIntervalSince(lastAttempt) < retryThrottleSeconds {
                return .available(inMemory)
            }

            // Attempt refresh
            let refreshed = attemptRefresh(now: now)
            switch refreshed {
            case .available(let newSnapshot):
                return .available(newSnapshot)
            case .unavailable:
                return .available(inMemory)
            }
        }

        // No in-memory snapshot: try loading runtime cache from disk
        if let (snapshot, cacheDate) = loadRuntimeCache() {
            let age = now.timeIntervalSince(cacheDate)

            if age < ttlSeconds {
                // Fresh cache: return without fetching
                return .available(snapshot)
            }

            // Stale cache: check throttle
            if let lastAttempt = effectiveLastRefreshAttempt(now: now),
               now.timeIntervalSince(lastAttempt) < retryThrottleSeconds {
                // Within throttle window: serve stale without fetching
                return .available(snapshot)
            }

            // Attempt refresh
            let refreshed = attemptRefresh(now: now)
            switch refreshed {
            case .available(let newSnapshot):
                return .available(newSnapshot)
            case .unavailable:
                // Refresh failed: serve stale cache
                return .available(snapshot)
            }
        }

        // No valid runtime cache (disk or in-memory): try bundled snapshot
        let bundled = loadBundledSnapshot()

        // Check throttle for no-cache case too
        if let lastAttempt = effectiveLastRefreshAttempt(now: now),
           now.timeIntervalSince(lastAttempt) < retryThrottleSeconds {
            // Throttled: serve bundled if available
            if let bundledSnapshot = bundled {
                return .available(bundledSnapshot)
            }
            return .unavailable
        }

        // Attempt refresh
        let refreshed = attemptRefresh(now: now)
        switch refreshed {
        case .available(let newSnapshot):
            return .available(newSnapshot)
        case .unavailable:
            // Refresh failed
            if let bundledSnapshot = bundled {
                return .available(bundledSnapshot)
            }
            return .unavailable
        }
    }

    // MARK: - Private

    private func effectiveLastRefreshAttempt(now: Date) -> Date? {
        // In-memory takes priority (from this process)
        if let inMemory = _inMemoryLastRefreshAttempt {
            return inMemory
        }
        // Fall back to persisted metadata
        return loadPersistedLastRefreshAttempt()
    }

    private func loadRuntimeCache() -> (CatalogSnapshot, Date)? {
        let cacheFile = cacheDirectory.appendingPathComponent("model-catalog-cache.json")
        guard let data = try? Data(contentsOf: cacheFile),
              let snapshot = try? JSONDecoder().decode(CatalogSnapshot.self, from: data),
              ExternalModelCatalog.isValidSnapshot(snapshot) else {
            return nil
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: cacheFile.path)
        let modDate = attrs?[.modificationDate] as? Date ?? Date.distantPast

        return (snapshot, modDate)
    }

    private func loadBundledSnapshot() -> CatalogSnapshot? {
        guard let url = bundledSnapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(CatalogSnapshot.self, from: data) else {
            return nil
        }
        // Strict validation: reject snapshots with missing source metadata,
        // empty providers, or any model entry with empty ID.
        guard ExternalModelCatalog.isValidSnapshot(snapshot) else {
            return nil
        }
        return snapshot
    }

    private func attemptRefresh(now: Date) -> CatalogAvailability {
        // Record the attempt
        _inMemoryLastRefreshAttempt = now
        persistRefreshAttempt(now)

        var primary: ParsedSource?
        var codexClient: ParsedSource?
        var secondary: ParsedSource?
        var errors: [String: String] = [:]

        do {
            let data = try fetcher.fetchModelsJSON()
            primary = ExternalModelCatalog.parseModelsJSON(data)
        } catch {
            errors["models.json"] = error.localizedDescription
        }

        do {
            let data = try fetcher.fetchCodexClientModels()
            codexClient = ExternalModelCatalog.parseCodexClientModels(data)
        } catch {
            errors["codex_client_models.json"] = error.localizedDescription
        }

        do {
            let data = try fetcher.fetchModelsDev()
            secondary = ExternalModelCatalog.parseModelsDev(data)
        } catch {
            errors["models.dev"] = error.localizedDescription
        }

        guard let merged = ExternalModelCatalog.mergeCatalogs(
            primary: primary,
            codexClient: codexClient,
            secondary: secondary,
            clock: clock
        ) else {
            // All sources failed or produced empty result
            let failure = CacheFailureMetadata(
                timestamp: ISO8601DateFormatter().string(from: now),
                sourceErrors: errors.isEmpty ? ["all": "no valid sources"] : errors
            )
            _inMemoryFailureMetadata = failure
            persistFailureMetadata(failure, now: now)
            return .unavailable
        }

        // Success: write cache and clear failure
        writeCache(merged, now: now)
        _inMemorySnapshot = merged
        _inMemorySnapshotDate = now
        _inMemoryFailureMetadata = nil
        clearPersistedFailure(now: now)

        return .available(merged)
    }

    private func writeCache(_ snapshot: CatalogSnapshot, now: Date) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot) else { return }

        let cacheFile = cacheDirectory.appendingPathComponent("model-catalog-cache.json")
        try? data.write(to: cacheFile, options: .atomic)

        // Update metadata
        let meta = CacheMetadata(
            cacheWrittenAt: ISO8601DateFormatter().string(from: now),
            lastRefreshAttemptAt: nil,
            lastFailure: nil
        )
        let metaData = try? encoder.encode(meta)
        let metaFile = cacheDirectory.appendingPathComponent("model-catalog-cache-meta.json")
        if let metaData = metaData {
            try? metaData.write(to: metaFile, options: .atomic)
        }
    }

    private func persistRefreshAttempt(_ date: Date) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        // Load existing metadata or create new
        var existing: CacheMetadata?
        let metaFile = cacheDirectory.appendingPathComponent("model-catalog-cache-meta.json")
        if let data = try? Data(contentsOf: metaFile),
           let meta = try? JSONDecoder().decode(CacheMetadata.self, from: data) {
            existing = meta
        }

        let updated = CacheMetadata(
            cacheWrittenAt: existing?.cacheWrittenAt ?? ISO8601DateFormatter().string(from: date),
            lastRefreshAttemptAt: ISO8601DateFormatter().string(from: date),
            lastFailure: existing?.lastFailure
        )

        if let metaData = try? encoder.encode(updated) {
            try? metaData.write(to: metaFile, options: .atomic)
        }
    }

    private func persistFailureMetadata(_ failure: CacheFailureMetadata, now: Date) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let meta = CacheMetadata(
            cacheWrittenAt: ISO8601DateFormatter().string(from: now),
            lastRefreshAttemptAt: failure.timestamp,
            lastFailure: failure
        )

        if let metaData = try? encoder.encode(meta) {
            let metaFile = cacheDirectory.appendingPathComponent("model-catalog-cache-meta.json")
            try? metaData.write(to: metaFile, options: .atomic)
        }
    }

    private func clearPersistedFailure(now: Date) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let meta = CacheMetadata(
            cacheWrittenAt: ISO8601DateFormatter().string(from: now),
            lastRefreshAttemptAt: nil,
            lastFailure: nil
        )

        if let metaData = try? encoder.encode(meta) {
            let metaFile = cacheDirectory.appendingPathComponent("model-catalog-cache-meta.json")
            try? metaData.write(to: metaFile, options: .atomic)
        }
    }

    private func loadPersistedLastRefreshAttempt() -> Date? {
        let metaFile = cacheDirectory.appendingPathComponent("model-catalog-cache-meta.json")
        guard let data = try? Data(contentsOf: metaFile),
              let meta = try? JSONDecoder().decode(CacheMetadata.self, from: data),
              let attemptStr = meta.lastRefreshAttemptAt else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: attemptStr) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: attemptStr)
    }
}

// MARK: - System Clock

struct SystemClock: CatalogClock {
    var now: Date { Date() }
}

// MARK: - URLSession Catalog Fetcher

/// Production CatalogFetcher that fetches catalog sources over HTTPS using URLSession.
/// Accepts an injected URLSession for testing; defaults to a session with a short timeout.
class URLSessionCatalogFetcher: CatalogFetcher {
    let session: URLSession
    let timeoutInterval: TimeInterval

    private let modelsJSONURL = URL(string: "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/models.json")!
    private let codexClientURL = URL(string: "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/codex_client_models.json")!
    private let modelsDevURL = URL(string: "https://models.dev/api.json")!

    init(session: URLSession? = nil, timeoutInterval: TimeInterval = 15.0) {
        self.timeoutInterval = timeoutInterval
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = timeoutInterval
            config.timeoutIntervalForResource = timeoutInterval * 2
            self.session = URLSession(configuration: config)
        }
    }

    func fetchModelsJSON() throws -> Data {
        return try fetchSynchronously(url: modelsJSONURL)
    }

    func fetchCodexClientModels() throws -> Data {
        return try fetchSynchronously(url: codexClientURL)
    }

    func fetchModelsDev() throws -> Data {
        return try fetchSynchronously(url: modelsDevURL)
    }

    private func fetchSynchronously(url: URL) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?

        session.dataTask(with: url) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            semaphore.signal()
        }.resume()

        // Deterministic timeout to prevent indefinite blocking
        let waitResult = semaphore.wait(timeout: .now() + timeoutInterval + 5.0)
        guard waitResult == .success else {
            throw NSError(domain: "URLSessionCatalogFetcher", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Request timed out for \(url.absoluteString)"])
        }

        if let error = resultError {
            throw error
        }

        // Check HTTP status code
        if let httpResponse = resultResponse as? HTTPURLResponse {
            guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
                throw NSError(domain: "URLSessionCatalogFetcher", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) for \(url.absoluteString)"])
            }
        }

        guard let data = resultData else {
            throw NSError(domain: "URLSessionCatalogFetcher", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No data received from \(url.absoluteString)"])
        }
        return data
    }
}

// MARK: - Production Model-List Catalog Provider

/// Production catalog provider that coordinates between CacheCoordinator
/// and connected-provider state for /v1/models responses.
/// Returns `.available(models)` when catalog data is present (possibly empty
/// if no connected providers), or `.unavailable` when no valid catalog exists.
class ProductionModelListCatalogProvider: ModelListCatalogProvider {
    private let coordinator: CacheCoordinator
    private let connectedProvidersProvider: () -> Set<String>

    init(
        coordinator: CacheCoordinator,
        connectedProvidersProvider: @escaping () -> Set<String>
    ) {
        self.coordinator = coordinator
        self.connectedProvidersProvider = connectedProvidersProvider
    }

    func fetchCatalogModels() -> CatalogModelsResult {
        let availability = coordinator.getCatalog()
        switch availability {
        case .available(let snapshot):
            let connected = connectedProvidersProvider()
            let models = ExternalModelCatalog.filterCatalog(
                snapshot: snapshot,
                connectedProviders: connected
            )
            return .available(models)
        case .unavailable:
            return .unavailable
        }
    }
}

extension ProductionModelListCatalogProvider {
    /// Creates a production provider with the given dependencies.
    /// All parameters are injectable for testing; production callers pass real values.
    ///
    /// - Parameters:
    ///   - connectedProvidersProvider: Closure returning the current set of connected
    ///     provider raw-value strings. Production: delegates to AppDelegate-owned ServerManager.
    ///   - fetcher: Catalog source fetcher. Production: URLSessionCatalogFetcher.
    ///   - cacheDirectory: Directory for runtime cache files.
    ///   - bundledSnapshotURL: Optional URL for bundled snapshot fallback.
    static func createDefault(
        connectedProvidersProvider: @escaping () -> Set<String>,
        fetcher: CatalogFetcher = URLSessionCatalogFetcher(),
        cacheDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-proxy-api"),
        bundledSnapshotURL: URL? = resolveBundledSnapshotURL(),
        clock: CatalogClock = SystemClock()
    ) -> ProductionModelListCatalogProvider {
        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDirectory,
            bundledSnapshotURL: bundledSnapshotURL
        )
        return ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: connectedProvidersProvider
        )
    }

    /// Resolves the URL for the bundled model catalog snapshot.
    /// Checks main-bundle resource URL first (CCProxy.app/Contents/Resources),
    /// then falls back to Bundle.module for SwiftPM test execution.
    /// - Parameters:
    ///   - mainBundleResourceURL: Override for Bundle.main.resourceURL (for testing).
    ///   - moduleResourceURL: Override for the module bundle snapshot URL (for testing).
    ///     When nil, the production default attempts Bundle.module resolution.
    static func resolveBundledSnapshotURL(
        mainBundleResourceURL: URL? = Bundle.main.resourceURL,
        moduleResourceURL: URL? = nil
    ) -> URL? {
        // 1. Main bundle resource URL (CCProxy.app/Contents/Resources/model-catalog-snapshot.json)
        if let resourceURL = mainBundleResourceURL {
            let url = resourceURL.appendingPathComponent("model-catalog-snapshot.json")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. Injected module resource URL (for testing)
        if let moduleURL = moduleResourceURL,
           FileManager.default.fileExists(atPath: moduleURL.path) {
            return moduleURL
        }

        // 3. Bundle.module fallback for SwiftPM test execution
        if let moduleURL = Bundle.module.url(
            forResource: "model-catalog-snapshot",
            withExtension: "json",
            subdirectory: "Resources"
        ) {
            return moduleURL
        }

        return nil
    }
}
