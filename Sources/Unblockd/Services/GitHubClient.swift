import Foundation

class GitHubClient: GitProvider, @unchecked Sendable {
    var type: ProviderType { .github }

    private let baseURL = "https://api.github.com"
    private var session: URLSession
    private var token: String?
    private var username: String?

    private var cachedUser: GitHubUser?

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setCredentials(username: String, token: String) {
        self.username = username
        self.token = token
    }

    // MARK: - API Calls

    private func makeRequest(to endpoint: String) async throws -> URLRequest {
        let urlString = endpoint.hasPrefix("http") ? endpoint : baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw GitProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let token = token, !token.isEmpty {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - GitProvider Implementation

    func fetchCurrentUser() async throws -> GitUser {
        let request = try await makeRequest(to: "/user")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitProviderError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw GitProviderError.unauthorized
            case 403, 429:
                throw GitProviderError.rateLimitExceeded
            default:
                throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
            }
        }

        let user = try JSONDecoder().decode(GitHubUser.self, from: data)
        self.cachedUser = user
        return GitUser(id: String(user.id), name: user.name ?? user.login, avatarURL: URL(string: user.avatar_url))
    }

    func fetchRepositories(query: String?) async throws -> [GitRepository] {
        // Strategy: Use /user/repos to get ALL accessible repos (owned + shared + orgs)
        // and filter client-side. This ensures consistency and proper scoping.
        // Limiting to 100 most recently updated for now.

        let endpoint = "/user/repos?type=all&sort=updated&per_page=\(AppConfig.Limits.githubSearchLimit)"

        let request = try await makeRequest(to: endpoint)
        let (data, httpResponse) = try await session.data(for: request)

        guard let response = httpResponse as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            let code = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0

            if let resp = httpResponse as? HTTPURLResponse {
                await MainActor.run {
                    RateLimitTracker.shared.track(response: resp, provider: .github)
                }
            }

            if let str = String(data: data, encoding: .utf8) {
                Log.error("[GitHub] API Error: \(code). Body: \(str)", category: Log.network)
            }

            switch code {
            case 401:
                throw GitProviderError.unauthorized
            case 403, 429:
                throw GitProviderError.rateLimitExceeded
            default:
                throw GitProviderError.apiError(statusCode: code)
            }
        }

        await MainActor.run {
            RateLimitTracker.shared.track(response: response, provider: .github)
        }

        let allRepos: [GitHubRepository]
        do {
            allRepos = try JSONDecoder().decode([GitHubRepository].self, from: data)
        } catch {
            Log.error("[GitHub] Decoding Error", error: error, category: Log.network)
            throw error
        }

        let filteredRepos: [GitHubRepository]
        if let q = query?.lowercased(), !q.isEmpty {
            filteredRepos = allRepos.filter {
                $0.name.lowercased().contains(q) || $0.full_name.lowercased().contains(q)
            }
        } else {
            filteredRepos = allRepos
        }

        return filteredRepos.map { repo in
            GitRepository(
                id: String(repo.id),
                name: repo.name,
                fullName: repo.full_name,
                url: URL(string: repo.html_url),
                provider: .github
            )
        }
    }

    func fetchPRs(for repo: GitRepository) async throws -> [PRItem] {
        if cachedUser == nil {
             try await _ = fetchCurrentUser()
        }
        guard let myUser = cachedUser else { throw GitProviderError.unauthorized }
        let (owner, repoName) = try splitRepositoryFullName(repo.fullName)

        async let openPRs = fetchOpenPRs(owner: owner, repoName: repoName)
        async let mergedPRs = fetchMergedPRs(owner: owner, repoName: repoName)

        let allPRs = try await (openPRs + mergedPRs)

        let reviewStates = try await fetchReviewStates(for: allPRs, owner: owner, repoName: repoName, myUserID: myUser.id)
        return allPRs.compactMap { pr -> PRItem? in
            let reviewState = reviewStates[pr.number]
            guard let prState = classify(pr: pr, me: myUser, reviewState: reviewState) else { return nil }

            return PRItem(
                id: "\(repo.fullName)/\(pr.number)",
                title: pr.title,
                repository: repo.name,
                author: pr.user.login,
                avatarURL: URL(string: pr.user.avatar_url),
                lastActivity: Self.dateFormatter.date(from: pr.updated_at) ?? Date(),
                state: prState,
                hasChangesRequested: reviewState?.hasChangesRequested ?? false,
                approvalCount: reviewState?.approvalCount ?? 0,
                reviewerCount: pr.requested_reviewers?.count ?? 0,
                url: URL(string: pr.html_url),
                isSnoozed: false,
                isDraft: pr.draft ?? false
            )
        }
    }

    // MARK: - Private Helpers

    private func splitRepositoryFullName(_ fullName: String) throws -> (owner: String, repoName: String) {
        let components = fullName.split(separator: "/", maxSplits: 1).map(String.init)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw GitProviderError.invalidURL
        }
        return (components[0], components[1])
    }

    private func fetchOpenPRs(owner: String, repoName: String) async throws -> [GitHubPR] {
        let endpoint = "/repos/\(owner)/\(repoName)/pulls?state=open"
        let request = try await makeRequest(to: endpoint)
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            await MainActor.run {
                RateLimitTracker.shared.track(response: httpResponse, provider: .github)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
                if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
                throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
            }
        }

        return try JSONDecoder().decode([GitHubPR].self, from: data)
    }

    private func fetchMergedPRs(owner: String, repoName: String) async throws -> [GitHubPR] {
         let days = UserDefaults.standard.integer(forKey: AppConfig.Keys.mergeLookbackDays)
         let lookbackDays = days > 0 ? days : AppConfig.Defaults.mergeLookbackDays
         let date = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()

         let dateString = Self.dateFormatter.string(from: date)

         let query = "repo:\(owner)/\(repoName)+is:pr+is:merged+updated:>\(dateString)"
         guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

         let endpoint = "/search/issues?q=\(encoded)"
         let request = try await makeRequest(to: endpoint)
         let (data, response) = try await session.data(for: request)

         if let httpResponse = response as? HTTPURLResponse {
             await MainActor.run {
                 RateLimitTracker.shared.track(response: httpResponse, provider: .github)
             }

             if !(200...299).contains(httpResponse.statusCode) {
                 if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
                 if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
                 throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
             }
         }

         let result = try JSONDecoder().decode(GitHubSearchResponse<GitHubPR>.self, from: data)
         return result.items
    }

    private struct ReviewState {
        let actedByMe: Bool
        let hasChangesRequested: Bool
        let approvalCount: Int

        static let empty = ReviewState(actedByMe: false, hasChangesRequested: false, approvalCount: 0)
    }

    private func fetchReviewStates(for prs: [GitHubPR], owner: String, repoName: String, myUserID: Int) async throws -> [Int: ReviewState] {
        let maxConcurrent = max(1, AppConfig.Limits.githubReviewFetchConcurrency)
        var fatalError: GitProviderError?

        let results = await withTaskGroup(of: (Int, Result<ReviewState, GitProviderError>).self) { group in
            var iterator = prs.makeIterator()
            var shouldScheduleMore = true

            func addTask(for pr: GitHubPR) {
                group.addTask {
                    do {
                        let state = try await self.fetchReviewState(owner: owner,
                                                                    repo: repoName,
                                                                    number: pr.number,
                                                                    myUserID: myUserID)
                        return (pr.number, .success(state))
                    } catch let error as GitProviderError {
                        switch error {
                        case .unauthorized, .rateLimitExceeded:
                            return (pr.number, .failure(error))
                        default:
                            return (pr.number, .success(.empty))
                        }
                    } catch {
                        return (pr.number, .success(.empty))
                    }
                }
            }

            for _ in 0..<maxConcurrent {
                guard let pr = iterator.next() else { break }
                addTask(for: pr)
            }

            var results: [Int: ReviewState] = [:]
            while let (number, result) = await group.next() {
                switch result {
                case .success(let state):
                    results[number] = state
                case .failure(let error):
                    fatalError = fatalError ?? error
                    shouldScheduleMore = false
                    group.cancelAll()
                }

                if shouldScheduleMore, let pr = iterator.next() {
                    addTask(for: pr)
                }
            }

            return results
        }

        if let fatalError {
            throw fatalError
        }

        return results
    }

    private func fetchReviewState(owner: String, repo: String, number: Int, myUserID: Int) async throws -> ReviewState {
        let endpoint = "/repos/\(owner)/\(repo)/pulls/\(number)/reviews"
        let request = try await makeRequest(to: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitProviderError.invalidResponse
        }

        await MainActor.run {
            RateLimitTracker.shared.track(response: httpResponse, provider: .github)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw GitProviderError.unauthorized
            case 403, 429:
                throw GitProviderError.rateLimitExceeded
            default:
                throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
            }
        }

        let reviews = try JSONDecoder().decode([GitHubReview].self, from: data)

        var latestReviews: [Int: GitHubReview] = [:]
        for review in reviews.sorted(by: { ($0.submitted_at ?? "") < ($1.submitted_at ?? "") }) {
            latestReviews[review.user.id] = review
        }

        let myLatestState = latestReviews[myUserID]?.state
        let actedByMe = myLatestState == .approved || myLatestState == .changesRequested
        let hasChangesRequested = latestReviews.values.contains { $0.state == .changesRequested }
        let approvalCount = latestReviews.values.filter { $0.state == .approved }.count

        return ReviewState(actedByMe: actedByMe, hasChangesRequested: hasChangesRequested, approvalCount: approvalCount)
    }

    private func classify(pr: GitHubPR, me: GitHubUser, reviewState: ReviewState?) -> PRItem.PRState? {
        if pr.draft == true {
            return pr.user.id == me.id ? .stale : .team
        }

        if pr.state == "closed" || pr.merged_at != nil {
            if pr.user.id == me.id {
                return .team
            }

            if reviewState?.actedByMe == true {
                return .team
            }

            let isReviewer = pr.requested_reviewers?.contains(where: { $0.id == me.id }) ?? false
            let isAssignee = pr.assignees?.contains(where: { $0.id == me.id }) ?? false
            return (isReviewer || isAssignee) ? .mergedNeedsReview : .team
        }

        if pr.user.id == me.id {
            return .stale
        }

        if reviewState?.actedByMe == true {
            return .waiting
        }

        if let reviewers = pr.requested_reviewers, reviewers.contains(where: { $0.id == me.id }) {
            return .needsReview
        }

        if let assignees = pr.assignees, assignees.contains(where: { $0.id == me.id }) {
            return .needsReview
        }

        return .team
    }
}
