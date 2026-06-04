import Foundation
import Combine
import AppKit

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

    /// Test seam: override the auth directory used by getConfigPath()
    var authDirectoryOverride: URL?

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

    /// Shared secret-key for API and dashboard access
    @Published var managementSecretKey: String = "" {
        didSet {
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
        "codex": "codex"
    ]

    init() {
        logBuffer = RingBuffer(capacity: maxLogLines)
        if let saved = UserDefaults.standard.dictionary(forKey: "enabledProviders") as? [String: Bool] {
            enabledProviders = saved
        }
        vercelGatewayEnabled = UserDefaults.standard.bool(forKey: "vercelGatewayEnabled")
        vercelApiKey = UserDefaults.standard.string(forKey: "vercelApiKey") ?? ""
        managementSecretKey = UserDefaults.standard.string(forKey: "managementSecretKey") ?? ""
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
        guard let resourcePath = Bundle.main.resourcePath else {
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
        
        // Get the config path
        let configPath = (resourcePath as NSString).appendingPathComponent("config.yaml")
        
        switch command {
        case .claudeLogin:
            authProcess.arguments = ["--config", configPath, "-claude-login"]
        case .codexLogin:
            authProcess.arguments = ["--config", configPath, "-codex-login"]
        }
        
        // Create pipes for output
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
        
        // Set environment to inherit from parent
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
                    // Process died quickly - check for error
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    NSLog("[Auth] Process died quickly - output: %@", output.isEmpty ? "(empty)" : String(output.prefix(200)))
                    
                    if output.contains("Opening browser") || output.contains("Attempting to open URL") {
                        // Browser opened but process finished (probably success)
                        NSLog("[Auth] Browser opened, process completed")
                        completion(true, "🌐 Browser opened for authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect when you're authenticated.")
                    } else {
                        // Real error
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

    private func saveApiKey(_ apiKey: String, provider: ServiceType, completion: @escaping (Bool, String) -> Void) {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")

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

        // Scan API-key provider auth files using consolidated helper
        let zaiApiKeys = scanApiKeys(for: ServiceType.zai, in: authDir)
        let minimaxApiKeys = scanApiKeys(for: ServiceType.minimax, in: authDir)
        let kimiApiKeys = scanApiKeys(for: ServiceType.kimi, in: authDir)

        // Build list of disabled providers
        var disabledProviders: [String] = []
        for (serviceKey, oauthKey) in Self.oauthProviderKeys {
            if !isProviderEnabled(serviceKey) {
                disabledProviders.append(oauthKey)
            }
        }

        // If no provider keys, no disabled providers, and no secret key, use bundled config
        guard !zaiApiKeys.isEmpty || !minimaxApiKeys.isEmpty || !kimiApiKeys.isEmpty || !disabledProviders.isEmpty || !managementSecretKey.isEmpty else {
            return bundledConfigPath
        }

        // Generate merged config
        guard let bundledContent = try? String(contentsOfFile: bundledConfigPath, encoding: .utf8) else {
            return bundledConfigPath
        }

        let escapedSecret = managementSecretKey
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")

        let baseContent: String
        if managementSecretKey.isEmpty {
            baseContent = bundledContent
        } else {
            baseContent = bundledContent.replacingOccurrences(
                of: "secret-key: \"\"",
                with: "secret-key: \"\(escapedSecret)\""
            )
        }

        var additionalConfig = ""

        // Build oauth-excluded-models section for disabled providers
        if !disabledProviders.isEmpty {
            additionalConfig += """

# Provider exclusions (auto-added by CCProxy)
# Disabled providers have all models excluded
oauth-excluded-models:

"""
            for provider in disabledProviders.sorted() {
                additionalConfig += "  \(provider):\n"
                additionalConfig += "    - \"*\"\n"
            }
        }

        let hasZai = !zaiApiKeys.isEmpty && isProviderEnabled(ServiceType.zai.rawValue)
        let hasMiniMax = !minimaxApiKeys.isEmpty && isProviderEnabled(ServiceType.minimax.rawValue)
        let hasKimi = !kimiApiKeys.isEmpty && isProviderEnabled(ServiceType.kimi.rawValue)

        // Build Claude-compatible upstream section for supported providers
        let claudeCompatibleProviders: [(enabled: Bool, prefix: String, comment: String, baseURL: String, apiKeys: [String], models: [String])] = [
            (
                hasZai,
                "zai",
                "Z.AI Claude-compatible upstream",
                "https://api.z.ai/api/anthropic",
                zaiApiKeys,
                [
                    "glm-5.1",
                    "glm-5",
                    "glm-5-turbo",
                    "glm-5v-turbo",
                    "glm-4.7",
                    "glm-4.7-flash",
                    "glm-4.6v",
                    "glm-4.5-air"
                ]
            ),
            (
                hasKimi,
                "kimi",
                "Kimi Claude-compatible upstream",
                "https://api.kimi.com/coding/",
                kimiApiKeys,
                [
                    "kimi-k2-turbo-preview"
                ]
            ),
            (
                hasMiniMax,
                "minimax",
                "MiniMax Claude-compatible upstream",
                "https://api.minimax.io/anthropic",
                minimaxApiKeys,
                [
                    "MiniMax-M2.7"
                ]
            )
        ]

        let enabledClaudeCompatibleProviders = claudeCompatibleProviders.filter(\.enabled)
        if !enabledClaudeCompatibleProviders.isEmpty {
            additionalConfig += "\n\n# Claude-compatible upstreams (auto-added by CCProxy)\nclaude-api-key:\n"
            for provider in enabledClaudeCompatibleProviders {
                for key in provider.apiKeys {
                    let escapedKey = key
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\"", with: "\\\"")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\t", with: "\\t")
                    additionalConfig += "  # \(provider.comment)\n"
                    additionalConfig += "  - api-key: \"\(escapedKey)\"\n"
                    additionalConfig += "    prefix: \"\(provider.prefix)\"\n"
                    additionalConfig += "    base-url: \"\(provider.baseURL)\"\n"
                    additionalConfig += "    models:\n"
                    for model in provider.models {
                        additionalConfig += "      - name: \"\(model)\"\n"
                    }
                }
            }
        }

        let mergedContent = baseContent + additionalConfig
        let mergedConfigPath = authDir.appendingPathComponent("merged-config.yaml")
        
        do {
            try mergedContent.write(to: mergedConfigPath, atomically: true, encoding: .utf8)
            // Set secure permissions (0600 - owner read/write only) since config contains API keys
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: mergedConfigPath.path)
            return mergedConfigPath.path
        } catch {
            NSLog("[ServerManager] Failed to write merged config: %@", error.localizedDescription)
            return bundledConfigPath
        }
    }
    
    func getLogs() -> [String] {
        return logBuffer.elements()
    }
    
    /// Scans auth directory for API key files matching the given provider prefix.
    private func scanApiKeys(for provider: ServiceType, in authDir: URL) -> [String] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { file in
            guard file.lastPathComponent.hasPrefix("\(provider.rawValue)-") && file.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apiKey = json["api_key"] as? String else { return nil }
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
}
