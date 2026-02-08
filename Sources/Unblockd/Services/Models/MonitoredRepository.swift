import Foundation

struct MonitoredRepository: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let workspace: String
    let name: String
    let fullName: String
    var provider: ProviderType? // Optional for backward compatibility

    var resolvedProvider: ProviderType {
        return provider ?? .bitbucket
    }
}

extension MonitoredRepository {
    func toGitRepository() -> GitRepository {
        return GitRepository(
            id: id,
            name: name,
            fullName: fullName,
            url: nil, // URL not persisted, reconstructed if needed or fetched
            provider: resolvedProvider
        )
    }
}
