import Foundation

enum ServiceType: String, CaseIterable {
    case claude
    case codex
    case zai
    case minimax
    case kimi
    case opencodeGo = "opencode-go"
    case xai

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .zai: return "Z.AI GLM"
        case .minimax: return "MiniMax"
        case .kimi: return "Kimi"
        case .opencodeGo: return "OpenCode Go"
        case .xai: return "xAI Grok"
        }
    }
}

/// Represents a single authenticated account
struct AuthAccount: Identifiable, Equatable {
    let id: String  // filename
    let email: String?
    let login: String?
    let type: ServiceType
    let expired: Date?
    let filePath: URL
    let isDisabled: Bool
    
    var isExpired: Bool {
        guard let expired = expired else { return false }
        return expired < Date()
    }
    
    var displayName: String {
        if let email = email, !email.isEmpty {
            return email
        }
        if let login = login, !login.isEmpty {
            return login
        }
        return id
    }
    
    static func == (lhs: AuthAccount, rhs: AuthAccount) -> Bool {
        lhs.id == rhs.id
    }
}

/// Tracks all accounts for a service type
struct ServiceAccounts {
    var type: ServiceType
    var accounts: [AuthAccount] = []
    
    var hasAccounts: Bool { !accounts.isEmpty }
    var activeCount: Int { accounts.filter { !$0.isExpired }.count }
    var expiredCount: Int { accounts.filter { $0.isExpired }.count }
}

class AuthManager: ObservableObject {
    @Published var serviceAccounts: [ServiceType: ServiceAccounts] = [:]
    @Published private(set) var providersRequiringReLogin: Set<ServiceType> = []

    var authDirectoryOverride: URL?

    private var providersWithQuarantinedLegacyCredentials: Set<ServiceType> = []
    
    private static let dateFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return [withFractional, standard]
    }()
    
    init() {
        // Initialize empty accounts for all service types
        for type in ServiceType.allCases {
            serviceAccounts[type] = ServiceAccounts(type: type)
        }
    }
    
    func accounts(for type: ServiceType) -> [AuthAccount] {
        serviceAccounts[type]?.accounts ?? []
    }
    
    func hasAccounts(for type: ServiceType) -> Bool {
        serviceAccounts[type]?.hasAccounts ?? false
    }
    
    func checkAuthStatus() {
        let authDir = authDirectoryOverride ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api")
        let quarantinedProviders = quarantineLegacyKimiCredentials(in: authDir)
        providersWithQuarantinedLegacyCredentials.formUnion(quarantinedProviders)
        
        var newAccounts: [ServiceType: [AuthAccount]] = [:]
        for type in ServiceType.allCases {
            newAccounts[type] = []
        }

        var hasValidKimiOAuthAccount = false
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let serviceType = ServiceType(rawValue: type.lowercased()) else {
                    continue
                }
                
                let email = json["email"] as? String
                let login = json["login"] as? String
                var expiredDate: Date?
                
                if let expiredStr = json["expired"] as? String {
                    for formatter in Self.dateFormatters {
                        if let date = formatter.date(from: expiredStr) {
                            expiredDate = date
                            break
                        }
                    }
                }
                
                let isDisabled = json["disabled"] as? Bool ?? false
                
                let account = AuthAccount(
                    id: file.lastPathComponent,
                    email: email,
                    login: login,
                    type: serviceType,
                    expired: expiredDate,
                    filePath: file,
                    isDisabled: isDisabled
                )
                
                newAccounts[serviceType]?.append(account)
                if serviceType == .kimi,
                   hasNonEmptyString(json["access_token"]),
                   !account.isExpired,
                   !account.isDisabled {
                    hasValidKimiOAuthAccount = true
                }
            }

            if hasValidKimiOAuthAccount {
                providersWithQuarantinedLegacyCredentials.remove(.kimi)
            }

            let reLoginProviders = providersWithQuarantinedLegacyCredentials
            
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(
                        type: type,
                        accounts: newAccounts[type] ?? []
                    )
                }
                self.providersRequiringReLogin = reLoginProviders
            }
        } catch {
            NSLog("[AuthStatus] Error checking auth status: %@", error.localizedDescription)
            let reLoginProviders = providersWithQuarantinedLegacyCredentials
            DispatchQueue.main.async {
                for type in ServiceType.allCases {
                    self.serviceAccounts[type] = ServiceAccounts(type: type)
                }
                self.providersRequiringReLogin = reLoginProviders
            }
        }
    }

    private func quarantineLegacyKimiCredentials(in authDir: URL) -> Set<ServiceType> {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: authDir, includingPropertiesForKeys: nil)
        } catch {
            NSLog("[AuthStatus] Error scanning auth directory for legacy credentials: %@", error.localizedDescription)
            return []
        }

        var quarantinedProviders: Set<ServiceType> = []
        for file in files where file.pathExtension == "json" {
            guard isLegacyKimiCredential(file) else { continue }

            let destination = nextLegacyCredentialURL(for: file)
            do {
                try FileManager.default.moveItem(at: file, to: destination)
                quarantinedProviders.insert(.kimi)
                NSLog("[AuthStatus] Quarantined legacy Kimi auth file: %@ -> %@", file.lastPathComponent, destination.lastPathComponent)
            } catch {
                NSLog("[AuthStatus] Failed to quarantine legacy Kimi auth file %@: %@", file.path, error.localizedDescription)
            }
        }

        return quarantinedProviders
    }

    private func isLegacyKimiCredential(_ file: URL) -> Bool {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type.lowercased() == ServiceType.kimi.rawValue,
              hasNonEmptyString(json["api_key"]) else {
            return false
        }

        return !hasNonEmptyString(json["access_token"])
    }

    private func hasNonEmptyString(_ value: Any?) -> Bool {
        guard let string = value as? String else { return false }
        return !string.isEmpty
    }

    private func nextLegacyCredentialURL(for file: URL) -> URL {
        let firstCandidate = file.appendingPathExtension("legacy")
        guard FileManager.default.fileExists(atPath: firstCandidate.path) else {
            return firstCandidate
        }

        var suffix = 1
        while true {
            let candidate = file.appendingPathExtension("legacy.\(suffix)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }
    
    /// Toggle the disabled state of a specific account's auth file
    func toggleAccountDisabled(_ account: AuthAccount) -> Bool {
        do {
            let data = try Data(contentsOf: account.filePath)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[AuthStatus] Failed to parse auth file as JSON: %@", account.filePath.path)
                return false
            }
            let currentlyDisabled = json["disabled"] as? Bool ?? false
            if !currentlyDisabled {
                let enabledCount = serviceAccounts[account.type]?.accounts.filter { !$0.isDisabled }.count ?? 0
                guard enabledCount > 1 else {
                    NSLog("[AuthStatus] Refusing to disable last enabled account for %@", account.type.rawValue)
                    return false
                }
            }
            json["disabled"] = !currentlyDisabled
            let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
            try updatedData.write(to: account.filePath, options: .atomic)
            NSLog("[AuthStatus] Toggled disabled=%d for: %@", !currentlyDisabled, account.filePath.path)
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to toggle disabled state: %@", error.localizedDescription)
            return false
        }
    }
    
    /// Delete a specific account's auth file
    func deleteAccount(_ account: AuthAccount) -> Bool {
        do {
            try FileManager.default.removeItem(at: account.filePath)
            NSLog("[AuthStatus] Deleted auth file: %@", account.filePath.path)
            // Refresh status
            checkAuthStatus()
            return true
        } catch {
            NSLog("[AuthStatus] Failed to delete auth file: %@", error.localizedDescription)
            return false
        }
    }
}
