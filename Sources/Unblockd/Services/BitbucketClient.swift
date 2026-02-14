import Foundation

enum GitProviderError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(statusCode: Int)
    case unauthorized
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from server"
        case .apiError(let code): return "Provider API error: \(code)"
        case .unauthorized: return "Unauthorized. Check your credentials."
        case .rateLimitExceeded: return "API Rate Limit Exceeded. Try again later."
        }
    }
}

class BitbucketClient: GitProvider, @unchecked Sendable {
    private let baseURL = "https://api.bitbucket.org/2.0"
    private var session: URLSession
    private static let pullRequestFields = [
        "values.id",
        "values.title",
        "values.state",
        "values.author",
        "values.destination",
        "values.comment_count",
        "values.links",
        "values.updated_on",
        "values.reviewers",
        "values.participants",
        "values.draft",
        "next"
    ].joined(separator: ",")

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var username: String?
    var appPassword: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setCredentials(username: String, token: String) {
        self.username = username
        self.appPassword = token
    }

    private func makeRequest(to endpoint: String) async throws -> URLRequest {
        let urlString = endpoint.hasPrefix("http") ? endpoint : baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw GitProviderError.invalidURL
        }
        try await checkRateLimit()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        applyAuthentication(to: &request)

        return request
    }

    private func applyAuthentication(to request: inout URLRequest) {
        let safeUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safePassword = appPassword?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let username = safeUsername, !username.isEmpty, let password = safePassword, !password.isEmpty {
            let loginString = "\(username):\(password)"
            if let loginData = loginString.data(using: .utf8) {
                let base64LoginString = loginData.base64EncodedString()
                request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
            }
        } else if let token = safePassword, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func checkRateLimit() async throws {
        // Advisory only: Record call. We don't block unless API says 429.
        await MainActor.run {
            RateLimitTracker.shared.recordCall()
        }
    }

    func fetchPullRequests(workspace: String, slug: String, nextURL: String? = nil) async throws -> [BitbucketPR] {
        let endpoint: String
        if let next = nextURL {
            endpoint = next
        } else {
             let fields = Self.pullRequestFields
             endpoint = "/repositories/\(workspace)/\(slug)/pullrequests?state=OPEN&pagelen=\(AppConfig.Limits.searchResultLimit)&fields=\(fields)"
        }

        let request = try await makeRequest(to: endpoint)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw GitProviderError.invalidResponse }

        if !(200...299).contains(httpResponse.statusCode) {
             if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
             if httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
             throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(BitbucketPagedResponse<BitbucketPR>.self, from: data)
        var prs = decoded.values

        if let next = decoded.next {
            let nextPRs = try await fetchPullRequests(workspace: workspace, slug: slug, nextURL: next)
            prs.append(contentsOf: nextPRs)
        }

        return prs
    }

    func fetchRecentlyMergedPullRequests(workspace: String, slug: String, nextURL: String? = nil) async throws -> [BitbucketPR] {
        let endpoint: String

        if let next = nextURL {
             endpoint = next
        } else {
            let days = UserDefaults.standard.integer(forKey: AppConfig.Keys.mergeLookbackDays)
            let lookbackDays = days > 0 ? days : AppConfig.Defaults.mergeLookbackDays

            let date = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
            let dateString = Self.dateFormatter.string(from: date)

            let query = "state=\"MERGED\" AND updated_on > \"\(dateString)\""

            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw GitProviderError.invalidURL
            }

             let fields = Self.pullRequestFields
             endpoint = "/repositories/\(workspace)/\(slug)/pullrequests?q=\(encodedQuery)&pagelen=50&fields=\(fields)"
        }

        let request = try await makeRequest(to: endpoint)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw GitProviderError.invalidResponse }

        if !(200...299).contains(httpResponse.statusCode) {
             if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
             if httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
             throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(BitbucketPagedResponse<BitbucketPR>.self, from: data)
        var prs = decoded.values

        if let next = decoded.next {
             let nextPRs = try await fetchRecentlyMergedPullRequests(workspace: workspace, slug: slug, nextURL: next)
             prs.append(contentsOf: nextPRs)
        }

        return prs
    }

    func fetchRepositories(role: String = "member", query: String? = nil, nextURL: String? = nil) async throws -> [BitbucketRepository] {
        let endpoint: String
        if let next = nextURL {
            endpoint = next
        } else {
            var components = URLComponents(string: baseURL + "/repositories")!
            var queryItems = [URLQueryItem(name: "role", value: role)]
            if let q = query, !q.isEmpty {
                 let bitbucketQuery = "name ~ \"\(q)\""
                 queryItems.append(URLQueryItem(name: "q", value: bitbucketQuery))
            }
            queryItems.append(URLQueryItem(name: "pagelen", value: "50"))
            components.queryItems = queryItems
            endpoint = components.url!.absoluteString
        }

        let request = try await makeRequest(to: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw GitProviderError.invalidResponse }

        if !(200...299).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
            if httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
            throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(BitbucketPagedResponse<BitbucketRepository>.self, from: data)
        var repos = decoded.values

        if let next = decoded.next {
            try await Task.sleep(nanoseconds: AppConfig.Timeouts.bitbucketPagingDelayNanoseconds)
            let nextRepos = try await fetchRepositories(role: role, query: query, nextURL: next)
            repos.append(contentsOf: nextRepos)
        }

        return repos
    }

    func fetchUser() async throws -> BitbucketUser {
        let endpoint = "/user"
        Log.info("[Bitbucket] fetchUser - Calling \(endpoint)", category: Log.network)
        Log.debug("[Bitbucket] fetchUser - Username: '\(username ?? "nil")' Token: \(appPassword != nil ? "***" : "nil")", category: Log.network)

        let request = try await makeRequest(to: endpoint)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            Log.info("[Bitbucket] fetchUser - Status: \(httpResponse.statusCode)", category: Log.network)
            if !(200...299).contains(httpResponse.statusCode) {
                if let body = String(data: data, encoding: .utf8) {
                    Log.error("[Bitbucket] fetchUser - Error body: \(body)", category: Log.network)
                }
                if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
                if httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
                throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
            }
        }

        return try JSONDecoder().decode(BitbucketUser.self, from: data)
    }

    var type: ProviderType { .bitbucket }

    private var cachedUserUUID: String?

    func fetchCurrentUser() async throws -> GitUser {
        let bbUser = try await fetchUser()
        self.cachedUserUUID = bbUser.uuid
        let avatarURL = URL(string: bbUser.links?.avatar?.href ?? "")
        return GitUser(id: bbUser.uuid, name: bbUser.display_name, avatarURL: avatarURL)
    }

    func fetchRepositories(query: String?) async throws -> [GitRepository] {
        let bbRepos = try await fetchRepositories(role: "member", query: query, nextURL: nil)
        return bbRepos.map { repo in
            GitRepository(
                id: repo.uuid,
                name: repo.name,
                fullName: repo.full_name,
                url: URL(string: repo.links?.html?.href ?? ""),
                provider: .bitbucket
            )
        }
    }

    func fetchPRs(for repo: GitRepository) async throws -> [PRItem] {
        Log.info("[Bitbucket] fetchPRs called for: \(repo.fullName)", category: Log.network)
        let parts = repo.fullName.components(separatedBy: "/")
        guard parts.count == 2 else {
            Log.warning("[Bitbucket] Invalid repo name format, skipping", category: Log.network)
            return []
        }
        let workspace = parts[0]
        let slug = parts[1]

        if cachedUserUUID == nil {
            Log.info("[Bitbucket] No cached UUID, fetching user...", category: Log.network)
            do {
                _ = try await fetchCurrentUser()
            } catch {
                Log.error("[Bitbucket] fetchCurrentUser failed", error: error, category: Log.network)
                throw error
            }
        }
        guard let myUUID = cachedUserUUID else {
            Log.error("[Bitbucket] UUID still nil after fetch - this shouldn't happen", category: Log.network)
            throw GitProviderError.unauthorized
        }
        Log.info("[Bitbucket] Using UUID: \(myUUID)", category: Log.network)

        let engine = PRRulesEngine(currentUserUUID: myUUID)

        return try await withThrowingTaskGroup(of: [BitbucketPR].self) { group in
            group.addTask {
                try await self.fetchPullRequests(workspace: workspace, slug: slug)
            }
            group.addTask {
                try await self.fetchRecentlyMergedPullRequests(workspace: workspace, slug: slug)
            }

            var allPRs: [BitbucketPR] = []
            for try await prs in group {
                allPRs.append(contentsOf: prs)
            }

            return allPRs.map { pr in
                var item = PRItem(from: pr)
                item.state = engine.classify(pr: pr, isDraft: pr.draft ?? false)
                return item
            }
        }
    }
}
