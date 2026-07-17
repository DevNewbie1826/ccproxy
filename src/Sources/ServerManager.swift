import Foundation
import Combine

private struct RingBuffer<Element> {
    private var storage: [Element?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0
    
    init(capacity: Int) {
        let safeCapacity = max(1, capacity)
        storage = Array(repeating: nil, count: safeCapacity)
    }
    
    mutating func append(_ element: Element) {
        let capacity = storage.count
        storage[tail] = element
        
        if count == capacity {
            head = (head + 1) % capacity
        } else {
            count += 1
        }
        
        tail = (tail + 1) % capacity
    }
    
    func elements() -> [Element] {
        let capacity = storage.count
        guard count > 0 else { return [] }
        
        var result: [Element] = []
        result.reserveCapacity(count)
        
        for index in 0..<count {
            let storageIndex = (head + index) % capacity
            if let value = storage[storageIndex] {
                result.append(value)
            }
        }
        
        return result
    }
}

class ServerManager: ObservableObject {
    private var process: Process?

    /// Serial queue protecting _activeAuthProcess access across threads
    /// (main-thread set/terminate vs termination-handler-thread clear).
    private let authProcessQueue = DispatchQueue(label: "com.devnewbie1826.ccproxy.auth-process", qos: .userInitiated)
    private var _activeAuthProcess: Process?

    /// Thread-safe access to the tracked active auth process. Internal for test
    /// access via @testable import.
    var activeAuthProcess: Process? {
        get { authProcessQueue.sync { _activeAuthProcess } }
        set { authProcessQueue.sync { _activeAuthProcess = newValue } }
    }

    @Published private(set) var isRunning = false
    private(set) var port = 8328

    /// Test seam: override the bundled config path used by getConfigPath()
    var bundledConfigPathOverride: String?

    var bundledResourcePathOverride: String?

    /// Test seam: override the auth directory used by getConfigPath()
    var authDirectoryOverride: URL?

    /// Test seam: override model names for specific provider prefixes in generated config.
    /// Model names may be provider-qualified (e.g. "opencode-go/kimi-k2.6"); the config
    /// generator strips the provider prefix for providers using prefix + force-model-prefix.
    /// When nil, model names are derived from the bundled catalog snapshot.
    var catalogModelsOverride: [String: [String]]?

    /// Returns model names for the given provider prefix from catalog data:
    /// 1. catalogModelsOverride if set for that prefix (test seam)
    /// 2. Model names loaded from runtime cache file first, then bundled snapshot
    /// 3. Empty array if neither is available
    /// Reads from disk on each call to observe runtime cache updates.
    private func catalogModelsForPrefix(_ prefix: String) -> [String] {
        if let override = catalogModelsOverride?[prefix] {
            return override
        }
        return loadCatalogModelNames()[prefix] ?? []
    }

    /// Loads model names for config generation using the same data sources as /v1/models:
    /// 1. Runtime cache file (same file CacheCoordinator writes to)
    /// 2. Bundled catalog snapshot
    /// This alignment ensures config and /v1/models do not diverge when a runtime cache exists.
    /// Config generation never triggers a network fetch; it reads whatever is on disk.
    private func loadCatalogModelNames() -> [String: [String]] {
        let authDir = authDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        // 1. Try the runtime cache file (same file CacheCoordinator writes to)
        let runtimeCacheFile = authDir.appendingPathComponent("model-catalog-cache.json")
        if let data = try? Data(contentsOf: runtimeCacheFile),
           let snapshot = try? JSONDecoder().decode(CatalogSnapshot.self, from: data),
           ExternalModelCatalog.isValidSnapshot(snapshot) {
            return ExternalModelCatalog.extractConfigModelNames(from: snapshot)
        }

        // 2. Fall back to bundled snapshot
        guard let url = ProductionModelListCatalogProvider.resolveBundledSnapshotURL(),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(CatalogSnapshot.self, from: data) else {
            return [:]
        }
        return ExternalModelCatalog.extractConfigModelNames(from: snapshot)
    }

    /// Provider enabled states - when disabled, models are excluded via oauth-excluded-models
    @Published var enabledProviders: [String: Bool] = [:] {
        didSet {
            UserDefaults.standard.set(enabledProviders, forKey: "enabledProviders")
        }
    }

    /// Vercel AI Gateway configuration for Claude requests
    @Published var vercelGatewayEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(vercelGatewayEnabled, forKey: "vercelGatewayEnabled")
            onVercelConfigChanged?()
        }
    }
    @Published var vercelApiKey: String = "" {
        didSet {
            UserDefaults.standard.set(vercelApiKey, forKey: "vercelApiKey")
            onVercelConfigChanged?()
        }
    }
    var onVercelConfigChanged: (() -> Void)?

    private var hasCompletedInitialization = false

    /// Shared secret-key for API and dashboard access
    @Published var managementSecretKey: String = "" {
        didSet {
            guard hasCompletedInitialization else { return }
            UserDefaults.standard.set(managementSecretKey, forKey: "managementSecretKey")
            _ = getConfigPath()
        }
    }

    private var logBuffer: RingBuffer<String>
    private let maxLogLines = 1000
    private let processQueue = DispatchQueue(label: "com.devnewbie1826.ccproxy.server-process", qos: .userInitiated)
    
    private enum Timing {
        static let readinessCheckDelay: TimeInterval = 1.0
        static let gracefulTerminationTimeout: TimeInterval = 2.0
        static let terminationPollInterval: TimeInterval = 0.05
    }
    
    var onLogUpdate: (([String]) -> Void)?

    /// OAuth provider keys used in config.yaml oauth-excluded-models
    static let oauthProviderKeys: [String: String] = [
        "claude": "claude",
        "codex": "codex",
        "kimi": "kimi",
        "xai": "xai"
    ]

    init() {
        logBuffer = RingBuffer(capacity: maxLogLines)
        if let saved = UserDefaults.standard.dictionary(forKey: "enabledProviders") as? [String: Bool] {
            enabledProviders = saved
        }
        vercelGatewayEnabled = UserDefaults.standard.bool(forKey: "vercelGatewayEnabled")
        vercelApiKey = UserDefaults.standard.string(forKey: "vercelApiKey") ?? ""
        managementSecretKey = UserDefaults.standard.string(forKey: "managementSecretKey") ?? ""
        hasCompletedInitialization = true
    }

    /// Check if a provider is enabled (defaults to true if not set)
    func isProviderEnabled(_ providerKey: String) -> Bool {
        return enabledProviders[providerKey] ?? true
    }

    /// Set provider enabled state and regenerate config (hot reload - no restart needed)
    func setProviderEnabled(_ providerKey: String, enabled: Bool) {
        enabledProviders[providerKey] = enabled
        addLog(enabled ? "✓ Enabled provider: \(providerKey)" : "⚠️ Disabled provider: \(providerKey)")

        // Regenerate config - CLIProxyAPI hot reloads config.yaml automatically
        _ = getConfigPath()
        addLog("Config updated (hot reload)")
    }
    
    deinit {
        // Terminate any active auth process using the same graceful+SIGKILL path
        terminateActiveAuthProcessIfNeeded(reason: "deinit cleanup")
        // Avoid asynchronous self capture during deallocation; only terminate the owned process.
        if let process, process.isRunning {
            process.terminate()
        }
        killOrphanedProcesses()
    }
    
    func start(completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
            completion(true)
            return
        }

        // Clean up any orphaned processes from previous crashes
        killOrphanedProcesses()

        // Use bundled binary from app bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            addLog("❌ Error: Could not find resource path")
            completion(false)
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("cli-proxy-api")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            addLog("❌ Error: cli-proxy-api binary not found at \(bundledPath)")
            completion(false)
            return
        }
        
        // Use config path (merged with Z.AI if keys exist)
        let configPath = getConfigPath()
        guard !configPath.isEmpty && FileManager.default.fileExists(atPath: configPath) else {
            addLog("❌ Error: config.yaml not found")
            completion(false)
            return
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: bundledPath)
        process?.arguments = ["-config", configPath]
        
        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog(output)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                self?.addLog("⚠️ \(output)")
            }
        }
        
        // Handle termination
        process?.terminationHandler = { [weak self] process in
            // Clear pipe handlers to prevent memory leaks
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.addLog("Server stopped with code: \(process.terminationStatus)")
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
            }
        }
        
        do {
            try process?.run()
            DispatchQueue.main.async {
                self.isRunning = true
            }
            addLog("✓ Server started on port \(port)")
            
            // Wait a bit to ensure it started successfully
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.readinessCheckDelay) { [weak self] in
                guard let self = self else { return }
                if let process = self.process, process.isRunning {
                    NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                    completion(true)
                } else {
                    self.addLog("⚠️ Server exited before becoming ready")
                    completion(false)
                }
            }
        } catch {
            addLog("❌ Failed to start server: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func stop(completion: (() -> Void)? = nil) {
        guard let process = process else {
            DispatchQueue.main.async {
                self.isRunning = false
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                completion?()
            }
            return
        }
        
        let pid = process.processIdentifier
        addLog("Stopping server (PID: \(pid))...")
        processQueue.async { [weak self] in
            guard let self = self else { return }
            
            // First try graceful termination (SIGTERM)
            process.terminate()
            
            // Wait up to configured interval for graceful termination
            let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
            }
            
            // If still running, force kill (SIGKILL)
            if process.isRunning {
                self.addLog("⚠️ Server didn't stop gracefully, force killing...")
                kill(pid, SIGKILL)
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                self.process = nil
                self.isRunning = false
                self.addLog("✓ Server stopped")
                NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
                completion?()
            }
        }
    }
    
    // MARK: - Auth Process Tracking
    
    /// Terminates any tracked active auth process before starting a new auth attempt.
    /// Uses graceful SIGTERM + SIGKILL fallback. Thread-safe via authProcessQueue.
    /// Internal for test access via @testable import.
    func terminateActiveAuthProcessIfNeeded(reason: String) {
        let authProcess = authProcessQueue.sync { () -> Process? in
            let proc = _activeAuthProcess
            _activeAuthProcess = nil
            return proc
        }

        guard let authProcess else {
            return
        }

        if authProcess.isRunning {
            addLog("⚠️ Terminating previous auth process (\(authProcess.processIdentifier)) before retry: \(reason)")
            authProcess.terminate()

            let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
            while authProcess.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
            }

            if authProcess.isRunning {
                kill(authProcess.processIdentifier, SIGKILL)
            }
        }
    }

    /// Clears the active auth process reference only if it matches the given process.
    /// Thread-safe via authProcessQueue. Internal for test access via @testable import.
    func clearActiveAuthProcess(_ process: Process) {
        authProcessQueue.sync {
            if _activeAuthProcess === process {
                _activeAuthProcess = nil
            }
        }
    }
    
    func runAuthCommand(_ command: AuthCommand, completion: @escaping (Bool, String) -> Void) {
        // Terminate any previous auth process before starting a new one
        terminateActiveAuthProcessIfNeeded(reason: "starting a new auth attempt")
        // Use bundled binary from app bundle
        guard let resourcePath = bundledResourcePathOverride ?? Bundle.main.resourcePath else {
            completion(false, "Could not find resource path")
            return
        }
        
        let bundledPath = (resourcePath as NSString).appendingPathComponent("cli-proxy-api")
        guard FileManager.default.fileExists(atPath: bundledPath) else {
            completion(false, "Binary not found at \(bundledPath)")
            return
        }
        
        let authProcess = Process()
        authProcess.executableURL = URL(fileURLWithPath: bundledPath)
        
        let configPath = (resourcePath as NSString).appendingPathComponent("config.yaml")
        
        switch command {
        case .claudeLogin:
            authProcess.arguments = ["--config", configPath, "-claude-login"]
        case .codexLogin:
            authProcess.arguments = ["--config", configPath, "-codex-login"]
        case .kimiLogin:
            authProcess.arguments = ["--config", configPath, "-kimi-login"]
        case .xaiLogin:
            authProcess.arguments = ["--config", configPath, "-xai-login"]
        }
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        authProcess.standardOutput = outputPipe
        authProcess.standardError = errorPipe
        authProcess.standardInput = inputPipe
        
        // For Codex login, avoid blocking on the manual callback prompt after ~15s.
        if case .codexLogin = command {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 12.0) {
                // Send newline before the prompt to keep waiting for browser callback.
                if authProcess.isRunning {
                    if let data = "\n".data(using: .utf8) {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        NSLog("[Auth] Sent newline to keep Codex login waiting for callback")
                    }
                }
            }
        }
        
        authProcess.environment = ProcessInfo.processInfo.environment
        
        do {
            NSLog("[Auth] Starting process: %@ with args: %@", bundledPath, authProcess.arguments?.joined(separator: " ") ?? "none")
            activeAuthProcess = authProcess
            try authProcess.run()
            addLog("✓ Authentication process started (PID: \(authProcess.processIdentifier)) - browser should open shortly")
            NSLog("[Auth] Process started with PID: %d", authProcess.processIdentifier)
            
            // Set up termination handler to detect when auth completes
            authProcess.terminationHandler = { [weak self] process in
                let exitCode = process.terminationStatus
                NSLog("[Auth] Process terminated with exit code: %d", exitCode)
                self?.clearActiveAuthProcess(process)
                
                if exitCode == 0 {
                    // Authentication completed successfully
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Give file system a moment to write the credential file
                        NotificationCenter.default.post(name: .authDirectoryChanged, object: nil)
                    }
                }
            }
            
            // Wait briefly to check if process crashes immediately
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
                if authProcess.isRunning {
                    NSLog("[Auth] Process running after wait, returning success")
                    completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                } else {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    NSLog("[Auth] Process died quickly - output: %@", output.isEmpty ? "(empty)" : String(output.prefix(200)))
                    
                    if output.contains("Opening browser") || output.contains("Attempting to open URL") {
                        NSLog("[Auth] Browser opened, process completed")
                        completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                    } else {
                        NSLog("[Auth] Process failed")
                        let message = error.isEmpty ? (output.isEmpty ? "Authentication process failed unexpectedly" : output) : error
                        completion(false, message)
                    }
                }
            }
        } catch {
            clearActiveAuthProcess(authProcess)
            NSLog("[Auth] Failed to start: %@", error.localizedDescription)
            completion(false, "Failed to start auth process: \(error.localizedDescription)")
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logLine = "[\(timestamp)] \(message)"
            
            self.logBuffer.append(logLine)
            self.onLogUpdate?(self.logBuffer.elements())
        }
    }
    
    /// Saves a Z.AI API key to the auth directory
    func saveZaiApiKey(_ apiKey: String, completion: @escaping (Bool, String) -> Void) {
        saveApiKey(apiKey, provider: .zai, completion: completion)
    }
    
    /// Saves a MiniMax API key to the auth directory
    func saveMiniMaxApiKey(_ apiKey: String, completion: @escaping (Bool, String) -> Void) {
        saveApiKey(apiKey, provider: .minimax, completion: completion)
    }
    
    /// Saves a Kimi API key to the auth directory
    func saveKimiApiKey(_ apiKey: String, completion: @escaping (Bool, String) -> Void) {
        saveApiKey(apiKey, provider: .kimi, completion: completion)
    }

    /// Saves an OpenCode Go API key to the auth directory
    func saveOpenCodeGoApiKey(_ apiKey: String, completion: @escaping (Bool, String) -> Void) {
        saveApiKey(apiKey, provider: .opencodeGo, completion: completion)
    }

    private func saveApiKey(_ apiKey: String, provider: ServiceType, completion: @escaping (Bool, String) -> Void) {
        switch provider {
        case .zai, .minimax, .opencodeGo:
            break
        case .claude, .codex, .kimi, .xai:
            completion(false, "\(provider.displayName) uses OAuth login and cannot save API keys")
            return
        }

        let authDir = authDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        do {
            try FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        } catch {
            completion(false, "Failed to create auth directory: \(error.localizedDescription)")
            return
        }

        let keyPreview = String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "\(provider.rawValue)-\(UUID().uuidString.prefix(8)).json"
        let filePath = authDir.appendingPathComponent(filename)

        let authData: [String: Any] = [
            "type": provider.rawValue,
            "email": keyPreview,
            "api_key": apiKey,
            "created": timestamp
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            try jsonData.write(to: filePath)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            addLog("✓ \(provider.displayName) API key saved to \(filename)")

            let wasRunning = isRunning
            if wasRunning {
                stop { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.start { _ in }
                    }
                }
            }

            completion(true, "API key saved successfully")
        } catch {
            completion(false, "Failed to save API key: \(error.localizedDescription)")
        }
    }

    /// Returns the config path to use, merging bundled config with API-key providers and provider exclusions
    func getConfigPath() -> String {
        let bundledConfigPath: String
        if let bundledConfigPathOverride {
            bundledConfigPath = bundledConfigPathOverride
        } else {
            guard let resourcePath = Bundle.main.resourcePath else {
                return ""
            }
            bundledConfigPath = (resourcePath as NSString).appendingPathComponent("config.yaml")
        }
        let authDir = authDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        let zaiApiKeys = scanApiKeys(for: ServiceType.zai, in: authDir)
        let minimaxApiKeys = scanApiKeys(for: ServiceType.minimax, in: authDir)
        let openCodeGoApiKeys = scanApiKeys(for: ServiceType.opencodeGo, in: authDir)

        var disabledProviders: [String] = []
        for (serviceKey, oauthKey) in Self.oauthProviderKeys {
            if !isProviderEnabled(serviceKey) {
                disabledProviders.append(oauthKey)
            }
        }

        let hasZai = !zaiApiKeys.isEmpty && isProviderEnabled(ServiceType.zai.rawValue)
        let hasMiniMax = !minimaxApiKeys.isEmpty && isProviderEnabled(ServiceType.minimax.rawValue)
        let hasOpenCodeGo = !openCodeGoApiKeys.isEmpty && isProviderEnabled(ServiceType.opencodeGo.rawValue)

        var upstreams: [ClaudeCompatibleUpstream] = []
        if hasZai {
            upstreams.append(ClaudeCompatibleUpstream(
                prefix: "zai",
                baseURL: "https://api.z.ai/api/anthropic",
                apiKeys: zaiApiKeys,
                models: catalogModelsForPrefix("zai")
            ))
        }
        if hasMiniMax {
            upstreams.append(ClaudeCompatibleUpstream(
                prefix: "minimax",
                baseURL: "https://api.minimax.io/anthropic",
                apiKeys: minimaxApiKeys,
                models: catalogModelsForPrefix("minimax")
            ))
        }
        if hasOpenCodeGo {
            upstreams.append(ClaudeCompatibleUpstream(
                prefix: "opencode-go",
                baseURL: "https://opencode.ai/zen/go/v1/messages",
                apiKeys: openCodeGoApiKeys,
                models: catalogModelsForPrefix("opencode-go").map { modelName in
                    if modelName.hasPrefix("opencode-go/") {
                        return String(modelName.dropFirst("opencode-go/".count))
                    }
                    return modelName
                }
            ))
        }

        do {
            return try ConfigComposer.writeMergedConfig(
                bundledConfigPath: bundledConfigPath,
                authDir: authDir,
                userConfigPath: authDir.appendingPathComponent("config.yaml"),
                upstreams: upstreams,
                disabledOAuthProviders: disabledProviders,
                managementSecretKey: managementSecretKey
            )
        } catch {
            NSLog("[ServerManager] Failed to compose merged config: %@", error.localizedDescription)
            return bundledConfigPath
        }
    }
    
    func getLogs() -> [String] {
        return logBuffer.elements()
    }
    
    // MARK: - Connected Providers

    /// Calculates the set of connected providers based on enabled state and valid credentials.
    /// OAuth providers (claude, codex, kimi, xai) require enabled state plus a non-disabled, non-expired auth file.
    /// API-key hosted providers (zai, minimax, opencode-go) require enabled state plus
    /// a non-disabled credential file with a non-empty api_key.
    /// Disabled providers and providers without valid credentials are excluded.
    /// - Parameter now: The current time for OAuth expiration checks (injectable for testing).
    /// - Returns: The set of ServiceTypes that are enabled and have valid credentials.
    func connectedProviders(now: Date = Date()) -> Set<ServiceType> {
        let authDir = authDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

        guard let files = try? FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil) else {
            return []
        }

        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterStandard = ISO8601DateFormatter()
        formatterStandard.formatOptions = [.withInternetDateTime]
        let dateFormatters = [formatterWithFractional, formatterStandard]
        let expirationFields = ["expired", "expires_at", "expiresAt", "expiration"]

        // Collect credential info per service type
        struct CredentialInfo {
            let isDisabled: Bool
            let isExpired: Bool
            let hasNonEmptyApiKey: Bool
            let hasNonEmptyAccessToken: Bool
        }

        var credentialsByType: [ServiceType: [CredentialInfo]] = [:]

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let typeStr = json["type"] as? String,
                  let serviceType = ServiceType(rawValue: typeStr.lowercased()) else {
                continue
            }

            let isDisabled = json["disabled"] as? Bool ?? false

            var isExpired = false
            for field in expirationFields {
                if let expiredStr = json[field] as? String {
                    for formatter in dateFormatters {
                        if let date = formatter.date(from: expiredStr) {
                            // Expired when expiration is at or before the current time
                            isExpired = date <= now
                            break
                        }
                    }
                    if isExpired { break }
                }
            }

            let apiKey = json["api_key"] as? String ?? ""
            let hasNonEmptyApiKey = !apiKey.isEmpty
            let accessToken = json["access_token"] as? String ?? ""
            let hasNonEmptyAccessToken = !accessToken.isEmpty

            let info = CredentialInfo(
                isDisabled: isDisabled,
                isExpired: isExpired,
                hasNonEmptyApiKey: hasNonEmptyApiKey,
                hasNonEmptyAccessToken: hasNonEmptyAccessToken
            )
            credentialsByType[serviceType, default: []].append(info)
        }

        var connected = Set<ServiceType>()

        let oauthProviderRawValues = Set(Self.oauthProviderKeys.keys)

        for serviceType in ServiceType.allCases {
            // Must be enabled
            guard isProviderEnabled(serviceType.rawValue) else { continue }

            let credentials = credentialsByType[serviceType] ?? []

            if oauthProviderRawValues.contains(serviceType.rawValue) {
                let requiresAccessToken = serviceType == .kimi || serviceType == .xai
                if credentials.contains(where: { credential in
                    guard !credential.isDisabled && !credential.isExpired else { return false }
                    return !requiresAccessToken || credential.hasNonEmptyAccessToken
                }) {
                    connected.insert(serviceType)
                }
            } else {
                if credentials.contains(where: { !$0.isDisabled && $0.hasNonEmptyApiKey }) {
                    connected.insert(serviceType)
                }
            }
        }

        return connected
    }
    
    /// Scans auth directory for API key files matching the given provider.
    /// Uses JSON "type" field as the authoritative provider identifier, matching
    /// the connectedProviders() logic. This alignment ensures config generation
    /// and connected-provider calculation do not diverge on credential detection.
    /// Filters out disabled credentials and empty API keys.
    private func scanApiKeys(for provider: ServiceType, in authDir: URL) -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { file in
            guard file.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apiKey = json["api_key"] as? String,
                  !apiKey.isEmpty,
                  (json["disabled"] as? Bool ?? false) == false
            else { return nil }
            // Use JSON type field as authoritative provider identifier
            guard let typeStr = json["type"] as? String,
                  typeStr.lowercased() == provider.rawValue else {
                return nil
            }
            return apiKey
        }
    }
    
    /// Orphan cleanup is intentionally disabled until it can be scoped to a CCProxy-owned process.
    private func killOrphanedProcesses() {
        // T02 avoids broad process-name matching. T05 will revisit safe stale-process cleanup.
    }
}

enum AuthCommand: Equatable {
    case claudeLogin
    case codexLogin
    case kimiLogin
    case xaiLogin
}
