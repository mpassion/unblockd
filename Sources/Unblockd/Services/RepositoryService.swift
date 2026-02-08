import Foundation

class RepositoryService: ObservableObject {
    @Published var monitoredRepositories: [MonitoredRepository] = []

    private let storageKey = AppConfig.Keys.monitoredRepos

    init() {
        load()
    }

    func add(repository: GitRepository) {
        let parts = repository.fullName.components(separatedBy: "/")
        let workspace = parts.first ?? ""
        let slug = parts.last ?? repository.name

        let repo = MonitoredRepository(
            id: repository.id,
            slug: slug,
            workspace: workspace,
            name: repository.name,
            fullName: repository.fullName,
            provider: repository.provider
        )

        // Use composite key (id + resolvedProvider) to prevent cross-provider collisions
        // resolvedProvider handles legacy repos where provider was nil (defaults to .bitbucket)
        if !monitoredRepositories.contains(where: { $0.id == repo.id && $0.resolvedProvider == repo.resolvedProvider }) {
            monitoredRepositories.append(repo)
            save()
        }
    }

    func remove(id: String, provider: ProviderType) {
        monitoredRepositories.removeAll { $0.id == id && $0.resolvedProvider == provider }
        save()
    }

    func isMonitored(id: String, provider: ProviderType) -> Bool {
        monitoredRepositories.contains { $0.id == id && $0.resolvedProvider == provider }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(monitoredRepositories) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MonitoredRepository].self, from: data) {
            monitoredRepositories = decoded
        }
    }
}
