import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedProvider: ProviderType
    @Published var username: String = ""
    @Published var token: String = ""
    @Published var isConnecting = false
    @Published var isSearching = false
    @Published var connectionError: String?
    @Published var connectedUsername: String?
    @Published var availableRepos: [GitRepository] = []
    @Published var serverQuery: String = ""

    private let dashboardViewModel: DashboardViewModel
    private var connectTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var connectRequestID = UUID()
    private var searchRequestID = UUID()

    init(dashboardViewModel: DashboardViewModel, selectedProvider: ProviderType = .bitbucket) {
        self.dashboardViewModel = dashboardViewModel
        self.selectedProvider = selectedProvider
        loadCredentials()
    }

    deinit {
        connectTask?.cancel()
        searchTask?.cancel()
    }

    func refreshCredentials() {
        loadCredentials()
    }

    func handleProviderChange() {
        cancelInFlightOperations()
        loadCredentials()
        availableRepos = []
        serverQuery = ""
        connectionError = nil
        connectedUsername = nil
    }

    func connectToProvider() {
        guard !token.isEmpty else { return }

        connectTask?.cancel()
        let requestID = UUID()
        connectRequestID = requestID

        isConnecting = true
        connectionError = nil
        connectedUsername = nil
        if !availableRepos.isEmpty { availableRepos = [] }

        let provider = selectedProvider
        let user = username
        let pwd = token

        connectTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                Log.info("🔵 Validating \(provider.displayName) token...", category: Log.network)
                let validatedUser = try await validateToken(for: provider, username: user, token: pwd)
                try Task.checkCancellation()

                try TokenManager.shared.saveToken(pwd, for: provider)
                if provider == .bitbucket && !user.isEmpty {
                    UserDefaults.standard.set(user, forKey: AppConfig.Keys.bitbucketUsername)
                }

                guard connectRequestID == requestID else { return }
                connectedUsername = validatedUser
                isConnecting = false
                connectTask = nil
            } catch is CancellationError {
                guard connectRequestID == requestID else { return }
                isConnecting = false
                connectTask = nil
            } catch {
                guard connectRequestID == requestID else { return }
                connectionError = error.localizedDescription
                isConnecting = false
                connectTask = nil
            }
        }
    }

    func searchRepositories() {
        guard !serverQuery.isEmpty else { return }

        searchTask?.cancel()
        let requestID = UUID()
        searchRequestID = requestID

        isSearching = true
        connectionError = nil

        let provider = selectedProvider
        let query = serverQuery

        searchTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                availableRepos = try await dashboardViewModel.searchRepositories(query: query, provider: provider)
                guard searchRequestID == requestID else { return }
                isSearching = false
                searchTask = nil
            } catch is CancellationError {
                guard searchRequestID == requestID else { return }
                isSearching = false
                searchTask = nil
            } catch {
                guard searchRequestID == requestID else { return }
                connectionError = "Search failed: \(error.localizedDescription)"
                isSearching = false
                searchTask = nil
            }
        }
    }

    private func cancelInFlightOperations() {
        connectTask?.cancel()
        searchTask?.cancel()
        connectTask = nil
        searchTask = nil
        isConnecting = false
        isSearching = false
    }

    private func validateToken(for provider: ProviderType, username: String, token: String) async throws -> String {
        let client = GitProviderFactory.makeProvider(for: provider, username: username, token: token)
        let user = try await client.fetchCurrentUser()
        return user.name
    }

    private func loadCredentials() {
        switch selectedProvider {
        case .bitbucket:
            username = UserDefaults.standard.string(forKey: AppConfig.Keys.bitbucketUsername) ?? ""
            token = TokenManager.shared.getToken(for: .bitbucket) ?? ""
        case .github:
            username = ""
            token = TokenManager.shared.getToken(for: .github) ?? ""
        case .gitlab:
            username = ""
            token = TokenManager.shared.getToken(for: .gitlab) ?? ""
        }
    }
}
