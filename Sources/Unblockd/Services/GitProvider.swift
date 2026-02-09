import Foundation

enum ProviderType: String, Codable, CaseIterable {
    case bitbucket
    case github
    case gitlab

    var displayName: String {
        switch self {
        case .bitbucket: return "Bitbucket"
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        }
    }
}

struct GitUser: Codable {
    let id: String
    let name: String
    let avatarURL: URL?
}

struct GitRepository: Identifiable, Codable {
    let id: String // UUID or ID
    let name: String
    let fullName: String // owner/slug
    let url: URL?
    let provider: ProviderType

    var monitoringKey: String {
        "\(provider.rawValue):\(id)"
    }
}

protocol GitProvider {
    var type: ProviderType { get }

    // Auth
    func setCredentials(username: String, token: String)
    func fetchCurrentUser() async throws -> GitUser

    // Repositories
    func fetchRepositories(query: String?) async throws -> [GitRepository]

    // PRs
    func fetchPRs(for repo: GitRepository) async throws -> [PRItem]
}
