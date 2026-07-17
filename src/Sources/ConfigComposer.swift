import Foundation
import Yams

struct ClaudeCompatibleUpstream: Equatable {
    let prefix: String
    let baseURL: String
    let apiKeys: [String]
    let models: [String]
    let excludedModels: [String]

    init(prefix: String, baseURL: String, apiKeys: [String], models: [String], excludedModels: [String] = []) {
        self.prefix = prefix
        self.baseURL = baseURL
        self.apiKeys = apiKeys
        self.models = models
        self.excludedModels = excludedModels
    }
}

enum ConfigComposer {
    enum CompositionError: Error {
        case emptyBundledConfig
        case bundledConfigIsNotMapping
    }

    /// Pure core: returns merged YAML string.
    static func compose(bundledYAML: String, userOverlayYAML: String?, upstreams: [ClaudeCompatibleUpstream], disabledOAuthProviders: [String], managementSecretKey: String) throws -> String {
        guard var root = try Yams.compose(yaml: bundledYAML) else {
            throw CompositionError.emptyBundledConfig
        }
        guard root.mapping != nil else {
            throw CompositionError.bundledConfigIsNotMapping
        }

        if let userOverlayYAML {
            guard let overlay = try Yams.compose(yaml: userOverlayYAML) else {
                throw CompositionError.emptyBundledConfig
            }
            root = merge(base: root, overlay: overlay)
        }

        if !managementSecretKey.isEmpty {
            setManagementSecret(managementSecretKey, in: &root)
        }

        appendClaudeAPIKeyEntries(for: upstreams, to: &root)
        setDisabledOAuthProviders(disabledOAuthProviders, in: &root)

        return try Yams.serialize(node: root, sortKeys: false)
    }

    /// IO wrapper: writes <authDir>/merged-config.yaml with posix 0600 and returns its path; when upstreams is empty AND disabledOAuthProviders is empty AND managementSecretKey is empty AND no user overlay file exists, returns bundledConfigPath without writing.
    static func writeMergedConfig(bundledConfigPath: String, authDir: URL, userConfigPath: URL?, upstreams: [ClaudeCompatibleUpstream], disabledOAuthProviders: [String], managementSecretKey: String) throws -> String {
        let overlayExists = userConfigPath.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        guard !upstreams.isEmpty || !disabledOAuthProviders.isEmpty || !managementSecretKey.isEmpty || overlayExists else {
            return bundledConfigPath
        }

        let bundledYAML = try String(contentsOfFile: bundledConfigPath, encoding: .utf8)
        let userOverlayYAML: String?
        if overlayExists, let userConfigPath {
            userOverlayYAML = try String(contentsOf: userConfigPath, encoding: .utf8)
        } else {
            userOverlayYAML = nil
        }
        let mergedYAML = try compose(
            bundledYAML: bundledYAML,
            userOverlayYAML: userOverlayYAML,
            upstreams: upstreams,
            disabledOAuthProviders: disabledOAuthProviders,
            managementSecretKey: managementSecretKey
        )

        try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        let mergedConfigURL = authDir.appendingPathComponent("merged-config.yaml")
        try mergedYAML.write(to: mergedConfigURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: mergedConfigURL.path)
        return mergedConfigURL.path
    }
}

private extension ConfigComposer {
    static func merge(base: Node, overlay: Node) -> Node {
        if let baseMapping = base.mapping, let overlayMapping = overlay.mapping {
            return .mapping(mergeMappings(base: baseMapping, overlay: overlayMapping))
        }
        if let baseSequence = base.sequence, let overlaySequence = overlay.sequence {
            return .sequence(mergeSequences(base: baseSequence, overlay: overlaySequence))
        }
        return overlay
    }

    static func mergeMappings(base: Node.Mapping, overlay: Node.Mapping) -> Node.Mapping {
        var result = base
        for pair in overlay {
            if let existing = result[pair.key] {
                result[pair.key] = merge(base: existing, overlay: pair.value)
            } else {
                result[pair.key] = pair.value
            }
        }
        return result
    }

    static func mergeSequences(base: Node.Sequence, overlay: Node.Sequence) -> Node.Sequence {
        let baseNodes = Array(base)
        let overlayNodes = Array(overlay)
        guard containsOnlyNamedMappings(baseNodes), containsOnlyNamedMappings(overlayNodes) else {
            return Node.Sequence(baseNodes + overlayNodes)
        }

        var mergedNodes = baseNodes
        var indexesByName: [String: Int] = [:]
        for (index, node) in mergedNodes.enumerated() {
            if let name = name(in: node) {
                indexesByName[name] = index
            }
        }

        for overlayNode in overlayNodes {
            guard let overlayName = name(in: overlayNode) else {
                mergedNodes.append(overlayNode)
                continue
            }
            if let index = indexesByName[overlayName] {
                mergedNodes[index] = overlayNode
            } else {
                indexesByName[overlayName] = mergedNodes.count
                mergedNodes.append(overlayNode)
            }
        }

        return Node.Sequence(mergedNodes)
    }

    static func containsOnlyNamedMappings(_ nodes: [Node]) -> Bool {
        guard !nodes.isEmpty else { return true }
        return nodes.allSatisfy { name(in: $0) != nil }
    }

    static func name(in node: Node) -> String? {
        node.mapping?["name"]?.string
    }

    static func setManagementSecret(_ secret: String, in root: inout Node) {
        var remoteManagement = root.mapping?["remote-management"]?.mapping ?? Node.Mapping([])
        remoteManagement["secret-key"] = stringNode(secret)
        root.mapping?["remote-management"] = .mapping(remoteManagement)
    }

    static func appendClaudeAPIKeyEntries(for upstreams: [ClaudeCompatibleUpstream], to root: inout Node) {
        let injectedEntries = claudeAPIKeyEntries(for: upstreams)
        guard !injectedEntries.isEmpty else { return }

        let existingEntries = root.mapping?["claude-api-key"]?.sequence.map(Array.init) ?? []
        root.mapping?["claude-api-key"] = .sequence(Node.Sequence(existingEntries + injectedEntries))
    }

    static func claudeAPIKeyEntries(for upstreams: [ClaudeCompatibleUpstream]) -> [Node] {
        var seen: Set<String> = []
        var entries: [Node] = []

        for upstream in upstreams {
            for apiKey in upstream.apiKeys {
                let deduplicationKey = "\(apiKey)\u{0}\(upstream.baseURL)"
                guard seen.insert(deduplicationKey).inserted else { continue }

                var pairs: [(Node, Node)] = [
                    (stringNode("api-key"), stringNode(apiKey)),
                    (stringNode("prefix"), stringNode(upstream.prefix)),
                    (stringNode("base-url"), stringNode(upstream.baseURL)),
                    (stringNode("models"), modelSequenceNode(upstream.models))
                ]
                if !upstream.excludedModels.isEmpty {
                    pairs.append((stringNode("excluded-models"), stringSequenceNode(upstream.excludedModels)))
                }
                entries.append(.mapping(Node.Mapping(pairs)))
            }
        }

        return entries
    }

    static func setDisabledOAuthProviders(_ disabledOAuthProviders: [String], in root: inout Node) {
        guard !disabledOAuthProviders.isEmpty else { return }
        let pairs = Array(Set(disabledOAuthProviders)).sorted().map { provider in
            (stringNode(provider), Node.sequence(Node.Sequence([stringNode("*")])))
        }
        root.mapping?["oauth-excluded-models"] = .mapping(Node.Mapping(pairs))
    }

    static func modelSequenceNode(_ models: [String]) -> Node {
        .sequence(Node.Sequence(models.map { model in
            .mapping(Node.Mapping([(stringNode("name"), stringNode(model))]))
        }))
    }

    static func stringSequenceNode(_ values: [String]) -> Node {
        .sequence(Node.Sequence(values.map(stringNode)))
    }

    static func stringNode(_ value: String) -> Node {
        Node(value, Tag(.str), .doubleQuoted)
    }
}
