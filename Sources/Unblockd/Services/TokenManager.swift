import Foundation

@MainActor
class TokenManager: ObservableObject {
    static let shared = TokenManager()

    private let bbKey = "unblockd_api_token" // Legacy key for Bitbucket
    private let ghKey = "unblockd_github_token"
    private let glKey = "unblockd_gitlab_token"

    @Published var cachedTokens: [ProviderType: String] = [:]

    private init() {
        refreshTokens()
    }

    func refreshTokens() {
        var tokens: [ProviderType: String] = [:]
        if let token = try? KeychainService.read(account: bbKey) {
            tokens[.bitbucket] = token
        }
        if let token = try? KeychainService.read(account: ghKey) {
            tokens[.github] = token
        }
        if let token = try? KeychainService.read(account: glKey) {
            tokens[.gitlab] = token
        }
        self.cachedTokens = tokens
    }

    func getToken(for provider: ProviderType = .bitbucket) -> String? {
        return cachedTokens[provider]
    }

    func saveToken(_ token: String, for provider: ProviderType) throws {
        var key = bbKey
        switch provider {
        case .bitbucket: key = bbKey
        case .github: key = ghKey
        case .gitlab: key = glKey
        }

        try KeychainService.save(password: token, account: key)
        cachedTokens[provider] = token
    }

    func deleteToken(for provider: ProviderType) throws {
        var key = bbKey
        switch provider {
        case .bitbucket: key = bbKey
        case .github: key = ghKey
        case .gitlab: key = glKey
        }

        try KeychainService.delete(account: key)
        cachedTokens.removeValue(forKey: provider)
    }
}
