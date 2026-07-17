import SwiftUI
import ServiceManagement

/// Maps service types to their bundled provider icon filenames.
enum ProviderIconNames {
    static func iconName(for serviceType: ServiceType) -> String {
        switch serviceType {
        case .claude: return "icon-claude.png"
        case .codex: return "icon-codex.png"
        case .zai: return "icon-zai.png"
        case .minimax: return "icon-minimax.png"
        case .kimi: return "icon-kimi.png"
        case .opencodeGo: return "icon-opencode-go.png"
        case .xai: return "icon-xai.png"
        }
    }
}

/// A single account row with disable toggle and remove button
struct AccountRowView: View {
    let account: AuthAccount
    let removeColor: Color
    let showDisableToggle: Bool
    let isLastEnabled: Bool
    let onToggleDisabled: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(account.isDisabled ? Color.gray : (account.isExpired ? Color.orange : Color.green))
                .frame(width: 6, height: 6)
            Text(account.displayName)
                .font(.caption)
                .foregroundColor(account.isDisabled ? .secondary.opacity(0.5) : (account.isExpired ? .orange : .secondary))
                .strikethrough(account.isDisabled)
            if account.isExpired && !account.isDisabled {
                Text("(expired)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if account.isDisabled {
                Text("(disabled)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if showDisableToggle {
                let canDisable = account.isDisabled || !isLastEnabled
                Button(action: onToggleDisabled) {
                    Text(account.isDisabled ? "Enable" : "Disable")
                        .font(.caption)
                        .foregroundColor(account.isDisabled ? .green : (canDisable ? .orange : .secondary.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!canDisable)
                .help(!canDisable ? "At least one account must remain enabled" : "")
                .onHover { inside in
                    if canDisable {
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }
            Button(action: onRemove) {
                HStack(spacing: 2) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                    Text("Remove")
                        .font(.caption)
                }
                .foregroundColor(removeColor)
            }
            .buttonStyle(.plain)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.leading, 28)
    }
}

/// Vercel AI Gateway controls shown in Claude expanded section
struct VercelGatewayControls: View {
    @ObservedObject var serverManager: ServerManager
    @State private var showingSaved = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $serverManager.vercelGatewayEnabled) {
                Text("Use Vercel AI Gateway")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Route Claude requests through Vercel AI Gateway for safer access to your Claude Max subscription")
            
            if serverManager.vercelGatewayEnabled {
                HStack(spacing: 8) {
                    Text("Vercel API key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("", text: $serverManager.vercelApiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .font(.caption)
                    
                    if showingSaved {
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button("Save") {
                            showingSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showingSaved = false
                            }
                        }
                        .controlSize(.small)
                        .disabled(serverManager.vercelApiKey.isEmpty)
                    }
                }
            }
        }
        .padding(.leading, 28)
        .padding(.top, 4)
    }
}

/// A row displaying a service with its connected accounts and add button
struct ServiceRow<ExtraContent: View>: View {
    let serviceType: ServiceType
    let iconName: String
    let accounts: [AuthAccount]
    let isAuthenticating: Bool
    let helpText: String?
    let reLoginRequired: Bool
    let isEnabled: Bool
    let isTemplateIcon: Bool
    let customTitle: String?
    let onConnect: () -> Void
    let onDisconnect: (AuthAccount) -> Void
    let onToggleDisabled: (AuthAccount) -> Void
    let onToggleEnabled: (Bool) -> Void
    var onExpandChange: ((Bool) -> Void)? = nil
    @ViewBuilder var extraContent: () -> ExtraContent

    @State private var isExpanded = false
    @State private var accountToRemove: AuthAccount?
    @State private var showingRemoveConfirmation = false

    private var activeCount: Int { accounts.filter { !$0.isExpired }.count }
    private var expiredCount: Int { accounts.filter { $0.isExpired }.count }
    private let removeColor = Color(red: 0xeb/255, green: 0x0f/255, blue: 0x0f/255)
    
    private var displayTitle: String {
        customTitle ?? serviceType.displayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack {
                // Enable/disable toggle
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggleEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(isEnabled ? "Disable this provider" : "Enable this provider")

                if let nsImage = IconCatalog.shared.image(named: iconName, resizedTo: NSSize(width: 20, height: 20), template: isTemplateIcon) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .renderingMode(isTemplateIcon ? .template : .original)
                        .frame(width: 20, height: 20)
                        .opacity(isEnabled ? 1.0 : 0.4)
                }
                Text(displayTitle)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                if isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                } else if isEnabled {
                    Button("Add Account") {
                        onConnect()
                    }
                    .controlSize(.small)
                }
            }
            
            // Account display (only shown when enabled)
            if isEnabled {
                let enabledCount = accounts.filter { !$0.isDisabled }.count
                if !accounts.isEmpty {
                    // Collapsible summary
                    HStack(spacing: 4) {
                        Text("\(accounts.count) connected account\(accounts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.green)

                        if enabledCount > 1 {
                            Text("• Round-robin w/ auto-failover")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 28)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }

                    // Expanded accounts list
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(accounts) { account in
                                AccountRowView(account: account, removeColor: removeColor, showDisableToggle: accounts.count > 1, isLastEnabled: !account.isDisabled && enabledCount <= 1, onToggleDisabled: {
                                    onToggleDisabled(account)
                                }) {
                                    accountToRemove = account
                                    showingRemoveConfirmation = true
                                }
                            }
                            extraContent()
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text(reLoginRequired ? "Re-login required" : "No connected accounts")
                        .font(.caption)
                        .foregroundColor(reLoginRequired ? .orange : .secondary)
                        .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 4)
        .help(helpText ?? "")
        .onAppear {
            if accounts.contains(where: { $0.isExpired }) {
                isExpanded = true
            }
        }
        .onChange(of: accounts) { newAccounts in
            if newAccounts.contains(where: { $0.isExpired }) {
                isExpanded = true
            }
        }
        .onChange(of: isExpanded) { newValue in
            onExpandChange?(newValue)
        }
        .alert("Remove Account", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                accountToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let account = accountToRemove {
                    onDisconnect(account)
                }
                accountToRemove = nil
            }
        } message: {
            if let account = accountToRemove {
                Text("Are you sure you want to remove \(account.displayName) from \(serviceType.displayName)?")
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var serverManager: ServerManager
    @StateObject private var authManager = AuthManager()
    @State private var launchAtLogin = false
    @State private var authenticatingService: ServiceType? = nil
    @State private var showingAuthResult = false
    @State private var authResultMessage = ""
    @State private var authResultSuccess = false
    @State private var fileMonitor: DispatchSourceFileSystemObject?
    @State private var showingZaiApiKeyPrompt = false
    @State private var zaiApiKey = ""
    @State private var showingMiniMaxApiKeyPrompt = false
    @State private var miniMaxApiKey = ""
    @State private var showingOpenCodeGoApiKeyPrompt = false
    @State private var openCodeGoApiKey = ""
    @State private var pendingRefresh: DispatchWorkItem?
    @State private var expandedRowCount = 0
    @State private var secretKeyDraft = ""
    
    private enum Timing {
        static let serverRestartDelay: TimeInterval = 0.3
        static let refreshDebounce: TimeInterval = 0.5
    }

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "v\(version)"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    HStack {
                        Text("Server status")
                        Spacer()
                        Button(action: {
                            if serverManager.isRunning {
                                serverManager.stop()
                            } else {
                                serverManager.start { _ in }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(serverManager.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(serverManager.isRunning ? "Running" : "Stopped")
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }

                    HStack {
                        Text("Auth files")
                        Spacer()
                        Button("Open Folder") {
                            openAuthFolder()
                        }
                    }
                }

                Section("Security") {
                    HStack(alignment: .center) {
                        Text("Secret key")
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        HStack(spacing: 8) {
                            SecureField("", text: $secretKeyDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)

                            Button("Save") {
                                serverManager.managementSecretKey = secretKeyDraft
                            }
                            .fixedSize()
                            .disabled(secretKeyDraft == serverManager.managementSecretKey)
                        }
                    }
                }

                Section("Services") {
                    ServiceRow(
                        serviceType: .claude,
                        iconName: ProviderIconNames.iconName(for: .claude),
                        accounts: authManager.accounts(for: .claude),
                        isAuthenticating: authenticatingService == .claude,
                        helpText: nil,
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("claude"),
                        isTemplateIcon: true,
                        customTitle: serverManager.vercelGatewayEnabled && !serverManager.vercelApiKey.isEmpty ? "Claude Code (via Vercel)" : nil,
                        onConnect: { connectService(.claude) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("claude", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) {
                        VercelGatewayControls(serverManager: serverManager)
                    }

                    ServiceRow(
                        serviceType: .codex,
                        iconName: ProviderIconNames.iconName(for: .codex),
                        accounts: authManager.accounts(for: .codex),
                        isAuthenticating: authenticatingService == .codex,
                        helpText: nil,
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("codex"),
                        isTemplateIcon: true,
                        customTitle: nil,
                        onConnect: { connectService(.codex) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("codex", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .xai,
                        iconName: ProviderIconNames.iconName(for: .xai),
                        accounts: authManager.accounts(for: .xai),
                        isAuthenticating: authenticatingService == .xai,
                        helpText: "xAI Grok provides access to Grok models via OAuth.",
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("xai"),
                        isTemplateIcon: true,
                        customTitle: nil,
                        onConnect: { connectService(.xai) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("xai", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .zai,
                        iconName: ProviderIconNames.iconName(for: .zai),
                        accounts: authManager.accounts(for: .zai),
                        isAuthenticating: authenticatingService == .zai,
                        helpText: "Z.AI GLM provides access to GLM-4.7 and other models via API key. Get your key at https://z.ai/manage-apikey/apikey-list",
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("zai"),
                        isTemplateIcon: true,
                        customTitle: nil,
                        onConnect: { showingZaiApiKeyPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("zai", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .minimax,
                        iconName: ProviderIconNames.iconName(for: .minimax),
                        accounts: authManager.accounts(for: .minimax),
                        isAuthenticating: authenticatingService == .minimax,
                        helpText: "MiniMax provides access to Claude-compatible models via API key. Get your key at https://platform.minimaxi.com",
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("minimax"),
                        isTemplateIcon: false,
                        customTitle: nil,
                        onConnect: { showingMiniMaxApiKeyPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("minimax", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .kimi,
                        iconName: ProviderIconNames.iconName(for: .kimi),
                        accounts: authManager.accounts(for: .kimi),
                        isAuthenticating: authenticatingService == .kimi,
                        helpText: "Kimi provides access to Moonshot AI models via OAuth.",
                        reLoginRequired: authManager.providersRequiringReLogin.contains(.kimi),
                        isEnabled: serverManager.isProviderEnabled("kimi"),
                        isTemplateIcon: false,
                        customTitle: nil,
                        onConnect: { connectService(.kimi) },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("kimi", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }

                    ServiceRow(
                        serviceType: .opencodeGo,
                        iconName: ProviderIconNames.iconName(for: .opencodeGo),
                        accounts: authManager.accounts(for: .opencodeGo),
                        isAuthenticating: authenticatingService == .opencodeGo,
                        helpText: "OpenCode Go provides low-cost coding models via subscription. Get your key at https://opencode.ai/ko/go",
                        reLoginRequired: false,
                        isEnabled: serverManager.isProviderEnabled("opencode-go"),
                        isTemplateIcon: false,
                        customTitle: nil,
                        onConnect: { showingOpenCodeGoApiKeyPrompt = true },
                        onDisconnect: { account in disconnectAccount(account) },
                        onToggleDisabled: { account in toggleAccountDisabled(account) },
                        onToggleEnabled: { enabled in serverManager.setProviderEnabled("opencode-go", enabled: enabled) },
                        onExpandChange: { expanded in expandedRowCount += expanded ? 1 : -1 }
                    ) { EmptyView() }
                }
            }
            .formStyle(.grouped)

            Spacer()
                .frame(height: 6)

            // Footer
            VStack(spacing: 4) {
                Text("CCProxy \(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 740)
        .sheet(isPresented: $showingZaiApiKeyPrompt) {
            VStack(spacing: 16) {
                Text("Z.AI API Key")
                    .font(.headline)
                Text("Enter your Z.AI API key from https://z.ai/manage-apikey/apikey-list")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $zaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingZaiApiKeyPrompt = false
                        zaiApiKey = ""
                    }
                    Button("Add Key") {
                        showingZaiApiKeyPrompt = false
                        startZaiAuth(apiKey: zaiApiKey)
                    }
                    .disabled(zaiApiKey.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .sheet(isPresented: $showingMiniMaxApiKeyPrompt) {
            VStack(spacing: 16) {
                Text("MiniMax API Key")
                    .font(.headline)
                Text("Enter your MiniMax API key from https://platform.minimaxi.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("", text: $miniMaxApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingMiniMaxApiKeyPrompt = false
                        miniMaxApiKey = ""
                    }
                    Button("Add Key") {
                        showingMiniMaxApiKeyPrompt = false
                        startMiniMaxAuth(apiKey: miniMaxApiKey)
                    }
                    .disabled(miniMaxApiKey.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .sheet(isPresented: $showingOpenCodeGoApiKeyPrompt) {
            VStack(spacing: 16) {
                Text("OpenCode Go API Key")
                    .font(.headline)
                Text("Enter your OpenCode Go API key from https://opencode.ai/ko/go")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("", text: $openCodeGoApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingOpenCodeGoApiKeyPrompt = false
                        openCodeGoApiKey = ""
                    }
                    Button("Add Key") {
                        showingOpenCodeGoApiKeyPrompt = false
                        startOpenCodeGoAuth(apiKey: openCodeGoApiKey)
                    }
                    .disabled(openCodeGoApiKey.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 400)
        }
        .onAppear {
            secretKeyDraft = serverManager.managementSecretKey
            authManager.checkAuthStatus()
            checkLaunchAtLogin()
            startMonitoringAuthDirectory()
        }
        .onDisappear {
            stopMonitoringAuthDirectory()
        }
        .alert("Authentication Result", isPresented: $showingAuthResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authResultMessage)
        }
    }

    // MARK: - Actions
    
    private func toggleAccountDisabled(_ account: AuthAccount) {
        if authManager.toggleAccountDisabled(account) {
            authResultSuccess = true
            authResultMessage = account.isDisabled
                ? "✓ Enabled \(account.displayName)"
                : "✓ Disabled \(account.displayName)"
            showingAuthResult = true
        } else {
            authResultSuccess = false
            authResultMessage = "Failed to update \(account.displayName). Please try again."
            showingAuthResult = true
        }
    }
    
    private func openAuthFolder() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        NSWorkspace.shared.open(authDir)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[SettingsView] Failed to toggle launch at login: %@", error.localizedDescription)
            }
        }
    }

    private func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func connectService(_ serviceType: ServiceType) {
        authenticatingService = serviceType
        NSLog("[SettingsView] Starting %@ authentication", serviceType.displayName)
        
        let command: AuthCommand
        switch serviceType {
        case .claude: command = .claudeLogin
        case .codex: command = .codexLogin
        case .kimi: command = .kimiLogin
        case .xai: command = .xaiLogin
        case .zai:
            authenticatingService = nil
            return // handled separately with API key prompt
        case .minimax:
            authenticatingService = nil
            return // handled separately with API key prompt
        case .opencodeGo:
            authenticatingService = nil
            return // handled separately with API key prompt
        }
        
        serverManager.runAuthCommand(command) { success, output in
            NSLog("[SettingsView] Auth completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: serviceType)
                    self.showingAuthResult = true
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Authentication failed. Please check if the browser opened and try again.\n\nDetails: \(output.isEmpty ? "No output from authentication process" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func successMessage(for serviceType: ServiceType) -> String {
        switch serviceType {
        case .claude:
            return "🌐 Browser opened for Claude Code authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .codex:
            return "🌐 Browser opened for Codex authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .kimi:
            return "🌐 Browser opened for Kimi authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .xai:
            return "🌐 Browser opened for xAI Grok authentication.\n\nPlease complete the login in your browser.\n\nThe app will automatically detect your credentials."
        case .zai:
            return "✓ Z.AI API key added successfully.\n\nYou can now use GLM models through the proxy."
        case .minimax:
            return "✓ MiniMax API key added successfully.\n\nYou can now use MiniMax models through the proxy."
        case .opencodeGo:
            return "✓ OpenCode Go API key added successfully.\n\nYou can now use OpenCode Go models through the proxy."
        }
    }
    
    private func startZaiAuth(apiKey: String) {
        authenticatingService = .zai
        NSLog("[SettingsView] Adding Z.AI API key")
        
        serverManager.saveZaiApiKey(apiKey) { success, output in
            NSLog("[SettingsView] Z.AI key save completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.zaiApiKey = ""
                
                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: .zai)
                    self.showingAuthResult = true
                    self.authManager.checkAuthStatus()
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Failed to save API key.\n\nDetails: \(output.isEmpty ? "Unknown error" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }
    
    private func startMiniMaxAuth(apiKey: String) {
        authenticatingService = .minimax
        NSLog("[SettingsView] Adding MiniMax API key")

        serverManager.saveMiniMaxApiKey(apiKey) { success, output in
            NSLog("[SettingsView] MiniMax key save completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.miniMaxApiKey = ""

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: .minimax)
                    self.showingAuthResult = true
                    self.authManager.checkAuthStatus()
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Failed to save API key.\n\nDetails: \(output.isEmpty ? "Unknown error" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func startOpenCodeGoAuth(apiKey: String) {
        authenticatingService = .opencodeGo
        NSLog("[SettingsView] Adding OpenCode Go API key")

        serverManager.saveOpenCodeGoApiKey(apiKey) { success, output in
            NSLog("[SettingsView] OpenCode Go key save completed - success: %d, output: %@", success, output)
            DispatchQueue.main.async {
                self.authenticatingService = nil
                self.openCodeGoApiKey = ""

                if success {
                    self.authResultSuccess = true
                    self.authResultMessage = self.successMessage(for: .opencodeGo)
                    self.showingAuthResult = true
                    self.authManager.checkAuthStatus()
                } else {
                    self.authResultSuccess = false
                    self.authResultMessage = "Failed to save API key.\n\nDetails: \(output.isEmpty ? "Unknown error" : output)"
                    self.showingAuthResult = true
                }
            }
        }
    }

    private func disconnectAccount(_ account: AuthAccount) {
        let wasRunning = serverManager.isRunning
        
        // Stop server, delete file, restart
        let cleanup = {
            if self.authManager.deleteAccount(account) {
                self.authResultSuccess = true
                self.authResultMessage = "✓ Removed \(account.displayName) from \(account.type.displayName)"
            } else {
                self.authResultSuccess = false
                self.authResultMessage = "Failed to remove account"
            }
            self.showingAuthResult = true
            
            if wasRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.serverRestartDelay) {
                    self.serverManager.start { _ in }
                }
            }
        }
        
        if wasRunning {
            serverManager.stop { cleanup() }
        } else {
            cleanup()
        }
    }
    
    // MARK: - File Monitoring
    
    private func startMonitoringAuthDirectory() {
        let authDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        try? FileManager.default.createDirectory(at: authDir, withIntermediateDirectories: true)
        
        let fileDescriptor = open(authDir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [self] in
            // Debounce rapid file changes to prevent UI flashing
            pendingRefresh?.cancel()
            let workItem = DispatchWorkItem {
                NSLog("[FileMonitor] Auth directory changed - refreshing status")
                authManager.checkAuthStatus()
            }
            pendingRefresh = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.refreshDebounce, execute: workItem)
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        fileMonitor = source
    }
    
    private func stopMonitoringAuthDirectory() {
        pendingRefresh?.cancel()
        fileMonitor?.cancel()
        fileMonitor = nil
    }
}
