#!/usr/bin/env swift

import Foundation

// MARK: - Configuration

/// Environment variable overrides allow testing without live network access:
///   MODEL_CATALOG_OUTPUT_PATH         — override snapshot output file path
///   MODEL_CATALOG_MODELS_JSON_URL     — override primary models.json URL (file:// for local fixtures)
///   MODEL_CATALOG_CODEX_CLIENT_URL    — override codex_client_models.json URL
///   MODEL_CATALOG_MODELS_DEV_URL      — override models.dev secondary URL

let env = ProcessInfo.processInfo.environment

let snapshotOutputPath = env["MODEL_CATALOG_OUTPUT_PATH"]
    ?? "src/Sources/Resources/model-catalog-snapshot.json"

let modelsJSONURL = URL(string: env["MODEL_CATALOG_MODELS_JSON_URL"]
    ?? "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json")!

let codexClientURL = URL(string: env["MODEL_CATALOG_CODEX_CLIENT_URL"]
    ?? "https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/codex_client_models.json")!

let modelsDevURL = URL(string: env["MODEL_CATALOG_MODELS_DEV_URL"]
    ?? "https://models.dev/api.json")!

let timeoutInterval: TimeInterval = 15.0

// CLIProxyAPI primary provider key → CCProxy provider ID normalization
let primaryProviderMapping: [String: String] = [
    "claude": "claude",
    "codex-free": "codex",
    "codex-team": "codex",
    "codex-plus": "codex",
    "codex-pro": "codex"
]

// CCProxy provider ID → models.dev provider key
let secondaryProviderMapping: [String: String] = [
    "zai": "zai-coding-plan",
    "minimax": "minimax-coding-plan",
    "kimi": "moonshotai",
    "opencode-go": "opencode-go"
]

// MARK: - Types

struct CatalogModelEntry: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    let displayName: String?
    let tier: String?
    let supplementalMetadata: [String: String]
}

struct CatalogSnapshot: Codable {
    let schemaVersion: String
    let generatedAt: String
    let sources: [String]
    let providerModels: [String: [CatalogModelEntry]]
}

// MARK: - Fetching

func fetchSynchronously(url: URL) throws -> Data {
    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultResponse: URLResponse?
    var resultError: Error?

    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = timeoutInterval
    config.timeoutIntervalForResource = timeoutInterval * 2
    let session = URLSession(configuration: config)

    session.dataTask(with: url) { data, response, error in
        resultData = data
        resultResponse = response
        resultError = error
        semaphore.signal()
    }.resume()

    let waitResult = semaphore.wait(timeout: .now() + timeoutInterval + 5.0)
    guard waitResult == .success else {
        throw NSError(domain: "SnapshotGenerator", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Request timed out for \(url.absoluteString)"])
    }

    if let error = resultError {
        throw error
    }

    if let httpResponse = resultResponse as? HTTPURLResponse {
        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            throw NSError(domain: "SnapshotGenerator", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) for \(url.absoluteString)"])
        }
    }

    guard let data = resultData else {
        throw NSError(domain: "SnapshotGenerator", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "No data received from \(url.absoluteString)"])
    }
    return data
}

// MARK: - Parsing

/// Parse CLIProxyAPI models.json: top-level provider-key object with array values.
/// Returns nil for malformed JSON or zero valid model entries.
func parseModelsJSON(_ data: Data) -> [String: [CatalogModelEntry]]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    var providerModels: [String: [CatalogModelEntry]] = [:]
    var totalValidModels = 0

    for sourceKey in json.keys.sorted() {
        guard let value = json[sourceKey],
              let descriptors = value as? [[String: Any]] else { continue }

        let ccproxyProvider: String
        let tier: String?

        if let mapped = primaryProviderMapping[sourceKey] {
            ccproxyProvider = mapped
            if sourceKey.hasPrefix("codex-") {
                tier = String(sourceKey.dropFirst("codex-".count))
            } else {
                tier = nil
            }
        } else {
            ccproxyProvider = sourceKey
            tier = nil
        }

        var models: [CatalogModelEntry] = []
        for descriptor in descriptors {
            guard let id = descriptor["id"] as? String, !id.isEmpty else { continue }

            let object = descriptor["object"] as? String ?? "model"
            let created = descriptor["created"] as? Int ?? 0
            let ownedBy = descriptor["owned_by"] as? String
                ?? descriptor["ownedBy"] as? String
                ?? ccproxyProvider
            let displayName = descriptor["display_name"] as? String
                ?? descriptor["displayName"] as? String

            let model = CatalogModelEntry(
                id: id,
                object: object,
                created: created,
                ownedBy: ownedBy,
                displayName: displayName,
                tier: tier,
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
    return providerModels
}

/// Parse CLIProxyAPI codex_client_models.json: object with `models` array.
/// `slug` becomes the model ID. All models go under "codex" provider.
func parseCodexClientModels(_ data: Data) -> [String: [CatalogModelEntry]]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let modelsArray = json["models"] as? [[String: Any]] else {
        return nil
    }

    var codexModels: [CatalogModelEntry] = []

    for descriptor in modelsArray {
        guard let slug = descriptor["slug"] as? String, !slug.isEmpty else { continue }

        let displayName = descriptor["display_name"] as? String
            ?? descriptor["displayName"] as? String
        let ownedBy = descriptor["owned_by"] as? String
            ?? descriptor["ownedBy"] as? String
            ?? "openai"

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

        let model = CatalogModelEntry(
            id: slug,
            object: "model",
            created: 0,
            ownedBy: ownedBy,
            displayName: displayName,
            tier: nil,
            supplementalMetadata: supplemental
        )
        codexModels.append(model)
    }

    guard !codexModels.isEmpty else { return nil }

    codexModels.sort { $0.id < $1.id }
    return ["codex": codexModels]
}

/// Parse models.dev api.json: top-level provider-key object with nested `models` objects.
func parseModelsDev(_ data: Data) -> [String: [CatalogModelEntry]]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    // Build reverse mapping: models.dev key → CCProxy provider
    var devToCCProxy: [String: String] = [:]
    for (ccproxy, devKey) in secondaryProviderMapping {
        devToCCProxy[devKey] = ccproxy
    }

    var providerModels: [String: [CatalogModelEntry]] = [:]
    var totalValidModels = 0

    for devProviderKey in json.keys.sorted() {
        guard let ccproxyProvider = devToCCProxy[devProviderKey],
              let providerValue = json[devProviderKey] as? [String: Any],
              let modelsObj = providerValue["models"] as? [String: Any] else {
            continue
        }

        var models: [CatalogModelEntry] = []
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

            let model = CatalogModelEntry(
                id: id,
                object: "model",
                created: created,
                ownedBy: ownedBy,
                displayName: displayName,
                tier: nil,
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
    return providerModels
}

// MARK: - Merge

func tierOrder(_ tier: String?) -> Int {
    switch tier {
    case "free": return 0
    case "team": return 1
    case "plus": return 2
    case "pro": return 3
    case nil: return -1
    default: return Int.max
    }
}

func deduplicate(_ entries: [CatalogModelEntry]) -> [CatalogModelEntry] {
    var seen = Set<String>()
    var result: [CatalogModelEntry] = []
    for entry in entries {
        if seen.insert(entry.id).inserted {
            result.append(entry)
        }
    }
    return result
}

/// Merge catalog sources with primary-first precedence.
func mergeCatalogs(
    primary: [String: [CatalogModelEntry]]?,
    codexClient: [String: [CatalogModelEntry]]?,
    secondary: [String: [CatalogModelEntry]]?
) -> [String: [CatalogModelEntry]]? {
    var mergedModels: [String: [CatalogModelEntry]] = [:]
    let knownProviders = Set(primaryProviderMapping.values)

    // 1. Insert primary models
    if let primary = primary {
        for provider in primary.keys.sorted() {
            guard knownProviders.contains(provider) else { continue }
            let models = primary[provider]!
            var entries = models
            entries.sort { a, b in
                if a.id != b.id { return a.id < b.id }
                return tierOrder(a.tier) < tierOrder(b.tier)
            }
            entries = deduplicate(entries)
            mergedModels[provider] = entries
        }
    }

    // 2. Supplement codex models with codex_client metadata by slug
    if let codexClient = codexClient {
        let codexClientModels = codexClient["codex"] ?? []
        if var codexEntries = mergedModels["codex"] {
            for clientModel in codexClientModels {
                if let idx = codexEntries.firstIndex(where: { $0.id == clientModel.id }) {
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
            let entries = deduplicate(codexClientModels)
            if !entries.isEmpty {
                mergedModels["codex"] = entries
            }
        }
    }

    // 3. Fill missing providers/models from secondary
    if let secondary = secondary {
        for provider in secondary.keys.sorted() {
            let models = secondary[provider]!
            if mergedModels[provider] == nil {
                let entries = deduplicate(models)
                if !entries.isEmpty {
                    mergedModels[provider] = entries
                }
            } else {
                let existingIds = Set(mergedModels[provider]!.map { $0.id })
                let newEntries = models.filter { !existingIds.contains($0.id) }
                if !newEntries.isEmpty {
                    mergedModels[provider]!.append(contentsOf: newEntries)
                }
            }
        }
    }

    guard !mergedModels.isEmpty else { return nil }

    // Sort all model entries by ID within each provider
    for provider in mergedModels.keys {
        mergedModels[provider]?.sort { $0.id < $1.id }
    }

    return mergedModels
}

// MARK: - Snapshot Validation

/// Check if an existing snapshot file is a valid, reusable snapshot.
/// Full Codable decode of the snapshot structure; requires:
///   - successful JSONDecoder decode as CatalogSnapshot (all fields present and type-correct)
///   - non-empty schemaVersion
///   - sources containing at least one known external catalog identifier
///   - non-empty providerModels
///   - every provider has a non-empty model array
///   - every model entry in every provider has a non-empty id
func isValidExistingSnapshot(_ url: URL) -> Bool {
    guard let data = try? Data(contentsOf: url) else {
        return false
    }

    // Full Codable decode: verifies all required fields exist with correct types,
    // including nested CatalogModelEntry fields (id, object, created, ownedBy, etc.)
    let snapshot: CatalogSnapshot
    do {
        snapshot = try JSONDecoder().decode(CatalogSnapshot.self, from: data)
    } catch {
        return false
    }

    // Non-empty schemaVersion
    guard !snapshot.schemaVersion.isEmpty else {
        return false
    }

    // Schema version must match the current policy version.
    // Old-schema snapshots are not valid fallbacks and must be regenerated.
    guard snapshot.schemaVersion == "2" else {
        return false
    }

    // Sources must reference at least one known external catalog
    let knownSources: Set<String> = ["models.json", "codex_client_models.json", "models.dev"]
    guard !snapshot.sources.isEmpty,
          snapshot.sources.contains(where: { knownSources.contains($0) }) else {
        return false
    }

    // Non-empty providerModels
    guard !snapshot.providerModels.isEmpty else {
        return false
    }

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

// MARK: - Main

var sources: [String] = []
var fetchErrors: [String: String] = [:]

// Fetch primary source
var primaryModels: [String: [CatalogModelEntry]]?
do {
    let data = try fetchSynchronously(url: modelsJSONURL)
    primaryModels = parseModelsJSON(data)
    if primaryModels != nil {
        sources.append("models.json")
        fputs("✓ Fetched models.json (\(data.count) bytes)\n", stdout)
    }
} catch {
    fetchErrors["models.json"] = error.localizedDescription
    fputs("⚠ Failed to fetch models.json: \(error.localizedDescription)\n", stderr)
}

// Fetch codex client models
var codexClientModels: [String: [CatalogModelEntry]]?
do {
    let data = try fetchSynchronously(url: codexClientURL)
    codexClientModels = parseCodexClientModels(data)
    if codexClientModels != nil {
        sources.append("codex_client_models.json")
        fputs("✓ Fetched codex_client_models.json (\(data.count) bytes)\n", stdout)
    }
} catch {
    fetchErrors["codex_client_models.json"] = error.localizedDescription
    fputs("⚠ Failed to fetch codex_client_models.json: \(error.localizedDescription)\n", stderr)
}

// Fetch secondary source
var secondaryModels: [String: [CatalogModelEntry]]?
do {
    let data = try fetchSynchronously(url: modelsDevURL)
    secondaryModels = parseModelsDev(data)
    if secondaryModels != nil {
        sources.append("models.dev")
        fputs("✓ Fetched models.dev (\(data.count) bytes)\n", stdout)
    }
} catch {
    fetchErrors["models.dev"] = error.localizedDescription
    fputs("⚠ Failed to fetch models.dev: \(error.localizedDescription)\n", stderr)
}

// Merge sources
guard let merged = mergeCatalogs(
    primary: primaryModels,
    codexClient: codexClientModels,
    secondary: secondaryModels
) else {
    // All sources failed to produce a valid merged catalog
    fputs("⚠ All external sources failed to produce a valid catalog\n", stderr)

    // Check for existing valid snapshot
    let existingURL = URL(fileURLWithPath: snapshotOutputPath)
    if isValidExistingSnapshot(existingURL) {
        fputs("✓ Reusing existing valid snapshot at \(snapshotOutputPath)\n", stdout)
        exit(0)
    }

    fputs("✗ No valid existing snapshot found and no sources available\n", stderr)
    exit(1)
}

// Deterministic generatedAt: preserve existing timestamp when semantic content is unchanged.
// This prevents wall-clock Date() from dirtying the tracked snapshot on every build.
let outputURL = URL(fileURLWithPath: snapshotOutputPath)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

// Encode new providerModels via Codable for deterministic comparison
let newSnapshot = CatalogSnapshot(
    schemaVersion: "2",
    generatedAt: "",
    sources: sources.isEmpty ? ["unknown"] : sources,
    providerModels: merged
)
guard let newEncoded = try? encoder.encode(newSnapshot),
      let newJson = try? JSONSerialization.jsonObject(with: newEncoded) as? [String: Any],
      let newPm = newJson["providerModels"] as? NSDictionary else {
    fputs("✗ Failed to encode new snapshot for comparison\n", stderr)
    exit(1)
}
let newPmData = try? JSONSerialization.data(withJSONObject: newPm, options: [.sortedKeys])

// Load existing snapshot's generatedAt and providerModels for comparison
var existingGeneratedAt: String? = nil
var existingPmData: Data? = nil
if let existingData = try? Data(contentsOf: outputURL),
   let existingJson = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
    existingGeneratedAt = existingJson["generatedAt"] as? String
    if let pm = existingJson["providerModels"] as? NSDictionary {
        existingPmData = try? JSONSerialization.data(withJSONObject: pm, options: [.sortedKeys])
    }
}

// Compare semantic content: if providerModels is identical, reuse existing generatedAt
let contentUnchanged = (newPmData != nil && existingPmData != nil &&
                         newPmData == existingPmData)

let finalGeneratedAt: String
if contentUnchanged, let existing = existingGeneratedAt {
    finalGeneratedAt = existing
    fputs("✓ Semantic content unchanged; preserving existing generatedAt\n", stdout)
} else {
    finalGeneratedAt = ISO8601DateFormatter().string(from: Date())
}

let snapshot = CatalogSnapshot(
    schemaVersion: "2",
    generatedAt: finalGeneratedAt,
    sources: sources.isEmpty ? ["unknown"] : sources,
    providerModels: merged
)

guard let snapshotData = try? encoder.encode(snapshot) else {
    fputs("✗ Failed to encode snapshot JSON\n", stderr)
    exit(1)
}

// Skip write entirely when encoded output matches existing file byte-for-byte
if let existingData = try? Data(contentsOf: outputURL), existingData == snapshotData {
    fputs("✓ Snapshot unchanged; skipping write\n", stdout)
    // Fall through to success summary
} else {
    // Atomic write: write to temp file, validate, then atomically replace
    let tempURL = outputURL.deletingLastPathComponent()
        .appendingPathComponent(".model-catalog-snapshot.tmp.json")

    do {
        let parentDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Write to temp file first
        try snapshotData.write(to: tempURL)

        // Validate temp file parses as valid JSON before replacing existing
        guard let validationData = try? Data(contentsOf: tempURL),
              let _ = try? JSONSerialization.jsonObject(with: validationData) else {
            fputs("✗ Temp file validation failed\n", stderr)
            try? FileManager.default.removeItem(at: tempURL)
            exit(1)
        }

        // Atomic replace: FileManager.replaceItem atomically replaces the destination
        // without removing it first, preventing data loss on failure.
        if FileManager.default.fileExists(atPath: outputURL.path) {
            _ = try FileManager.default.replaceItem(at: outputURL, withItemAt: tempURL,
                                                    backupItemName: nil, options: [],
                                                    resultingItemURL: nil)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: outputURL)
        }
    } catch {
        fputs("✗ Failed to write snapshot: \(error.localizedDescription)\n", stderr)
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        exit(1)
    }
}

let providerCount = merged.keys.count
let modelCount = merged.values.reduce(0) { $0 + $1.count }
fputs("✓ Generated snapshot: \(providerCount) providers, \(modelCount) models\n", stdout)
fputs("✓ Written to \(snapshotOutputPath)\n", stdout)

if !fetchErrors.isEmpty {
    for (source, error) in fetchErrors.sorted(by: { $0.key < $1.key }) {
        fputs("  Note: \(source) fetch failed: \(error)\n", stderr)
    }
}
