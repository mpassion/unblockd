import Foundation

class GitLabClient: GitProvider {
    let type: ProviderType = .gitlab
    private let baseURL = URL(string: "https://gitlab.com/api/v4")!
    private let session: URLSession

    private var token: String = ""
    private var username: String = ""

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setCredentials(username: String, token: String) {
        self.username = username
        self.token = token
    }

    func fetchCurrentUser() async throws -> GitUser {
        let url = baseURL.appendingPathComponent("user")
        let glUser: GitLabUser = try await request(url: url)

        if glUser.username.isEmpty { throw GitProviderError.unauthorized }

        return GitUser(
            id: String(glUser.id),
            name: glUser.name,
            avatarURL: glUser.avatarUrl.flatMap { URL(string: $0) }
        )
    }

    func fetchRepositories(query: String?) async throws -> [GitRepository] {
        var components = URLComponents(url: baseURL.appendingPathComponent("projects"), resolvingAgainstBaseURL: true)!

        var queryItems = [
            URLQueryItem(name: "membership", value: "true"),
            URLQueryItem(name: "simple", value: "true"),
            URLQueryItem(name: "min_access_level", value: "30"), // Developer access
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "order_by", value: "last_activity_at")
        ]

        if let searchText = query, !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchText))
        }

        components.queryItems = queryItems

        guard let url = components.url else { throw URLError(.badURL) }

        let projects: [GitLabProject] = try await request(url: url)

        return projects.map { proj in
            GitRepository(
                id: String(proj.id),
                name: proj.name,
                fullName: proj.pathWithNamespace,
                url: URL(string: proj.webUrl),
                provider: .gitlab
            )
        }
    }

    func fetchPRs(for repo: GitRepository) async throws -> [PRItem] {
        guard let projectID = Int(repo.id) else { return [] }

        let currentUser = try await fetchCurrentUser()

        let openMRs = try await fetchOpenMRs(projectID: projectID)
        let mergedMRs = try await fetchMergedMRs(projectID: projectID)
        let allMRs = openMRs + mergedMRs

        var items: [PRItem] = []

        for mr in allMRs {
            let approvalState: GitLabApprovalState?
            do {
                approvalState = try await fetchApprovalState(projectID: projectID, mrIID: mr.iid)
            } catch let error as GitProviderError {
                // Propagate fatal errors; degrade gracefully for non-critical per-MR failures.
                switch error {
                case .unauthorized, .rateLimitExceeded:
                    throw error
                default:
                    approvalState = nil
                }
            } catch {
                approvalState = nil
            }

            let isReviewer = mr.reviewers?.contains { String($0.id) == currentUser.id } ?? false
            let isAssignee = mr.assignees?.contains { String($0.id) == currentUser.id } ?? false
            let isAuthor = String(mr.author.id) == currentUser.id
            let approvedByMe = approvalState?.approvedBy.contains { String($0.user.id) == currentUser.id } ?? false

            // Extra reviewers API call only for MRs where requested-changes context exists and
            // we still need to determine whether current user already acted with requested changes.
            var myReviewerState: String?
            let shouldFetchReviewers = mr.state == "opened"
                && (isReviewer || isAssignee)
                && !isAuthor
                && !approvedByMe
                && mr.detailedMergeStatus?.lowercased() == "requested_changes"

            if shouldFetchReviewers {
                do {
                    myReviewerState = try await fetchMyReviewerState(projectID: projectID, mrIID: mr.iid, currentUserID: currentUser.id)
                } catch let error as GitProviderError {
                    switch error {
                    case .unauthorized, .rateLimitExceeded:
                        throw error
                    default:
                        myReviewerState = nil
                    }
                } catch {
                    myReviewerState = nil
                }
            }

            let item = mapToPRItem(
                mr: mr,
                repositoryName: repo.name,
                approvalState: approvalState,
                myReviewerState: myReviewerState,
                currentUserID: currentUser.id
            )
            items.append(item)
        }

        return items
    }

    private func fetchOpenMRs(projectID: Int) async throws -> [GitLabMergeRequest] {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent("\(projectID)")
            .appendingPathComponent("merge_requests")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "state", value: "opened"),
            URLQueryItem(name: "scope", value: "all"),
            URLQueryItem(name: "per_page", value: "50")
        ]

        guard let requestUrl = components.url else { return [] }
        return try await request(url: requestUrl)
    }

    private func fetchMergedMRs(projectID: Int) async throws -> [GitLabMergeRequest] {
        let days = UserDefaults.standard.integer(forKey: AppConfig.Keys.mergeLookbackDays)
        let lookbackDays = days > 0 ? days : AppConfig.Defaults.mergeLookbackDays

        let date = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)

        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent("\(projectID)")
            .appendingPathComponent("merge_requests")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "state", value: "merged"),
            URLQueryItem(name: "scope", value: "all"),
            URLQueryItem(name: "updated_after", value: dateString),
            URLQueryItem(name: "per_page", value: "50")
        ]

        guard let requestUrl = components.url else { return [] }
        return try await request(url: requestUrl)
    }

    private func fetchApprovalState(projectID: Int, mrIID: Int) async throws -> GitLabApprovalState? {
        let url = baseURL
             .appendingPathComponent("projects")
             .appendingPathComponent("\(projectID)")
             .appendingPathComponent("merge_requests")
             .appendingPathComponent("\(mrIID)")
             .appendingPathComponent("approvals")

        do {
            let state: GitLabApprovalState = try await request(url: url)
            return state
        } catch let error as GitProviderError {
            // Some projects may not expose approvals endpoint/details for current permissions.
            // Treat it as missing optional metadata, not fatal.
            if case .apiError(let statusCode) = error, statusCode == 404 {
                return nil
            }
            throw error
        }
    }

    private func fetchReviewerStatuses(projectID: Int, mrIID: Int) async throws -> [GitLabReviewerStatus]? {
        let url = baseURL
            .appendingPathComponent("projects")
            .appendingPathComponent("\(projectID)")
            .appendingPathComponent("merge_requests")
            .appendingPathComponent("\(mrIID)")
            .appendingPathComponent("reviewers")

        do {
            let statuses: [GitLabReviewerStatus] = try await request(url: url)
            return statuses
        } catch let error as GitProviderError {
            if case .apiError(let statusCode) = error, statusCode == 404 {
                return nil
            }
            throw error
        }
    }

    private func fetchMyReviewerState(projectID: Int, mrIID: Int, currentUserID: String) async throws -> String? {
        guard let statuses = try await fetchReviewerStatuses(projectID: projectID, mrIID: mrIID) else {
            return nil
        }

        return statuses.first { String($0.user.id) == currentUserID }?.state.lowercased()
    }

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func mapToPRItem(
        mr: GitLabMergeRequest,
        repositoryName: String,
        approvalState: GitLabApprovalState?,
        myReviewerState: String?,
        currentUserID: String
    ) -> PRItem {

        let approvedByMe = approvalState?.approvedBy.contains { String($0.user.id) == currentUserID } ?? false
        let requestedChangesByMe = myReviewerState == "requested_changes"
        let hasActedByMe = approvedByMe || requestedChangesByMe

        let isReviewer = mr.reviewers?.contains { String($0.id) == currentUserID } ?? false
        let isAssignee = mr.assignees?.contains { String($0.id) == currentUserID } ?? false
        let isAuthor = String(mr.author.id) == currentUserID

        var state: PRItem.PRState = .unknown

        if mr.state == "merged" {
            if (isReviewer || isAssignee) && !hasActedByMe && !isAuthor {
                state = .mergedNeedsReview
            } else {
                state = .team
            }
        } else if isAuthor {
            state = .stale
        } else if hasActedByMe {
            state = .waiting
        } else if isReviewer || isAssignee {
            state = .needsReview
        } else {
            state = .team
        }

        if mr.isDraft && mr.state != "merged" {
             if isAuthor {
                 state = .stale
             } else {
                 state = .team
             }
        }

        let lastActivity = Self.dateFormatter.date(from: mr.updatedAt) ?? Date()
        let hasChangesRequested = mr.detailedMergeStatus?.lowercased() == "requested_changes"

        return PRItem(
            id: String(mr.id),
            title: mr.title,
            repository: repositoryName,
            author: mr.author.name,
            avatarURL: mr.author.avatarUrl.flatMap { URL(string: $0) },
            lastActivity: lastActivity,
            state: state,
            hasChangesRequested: hasChangesRequested,
            approvalCount: approvalState?.approvedBy.count ?? 0,
            reviewerCount: mr.reviewers?.count ?? 0,
            url: URL(string: mr.webUrl),
            isSnoozed: false,
            isDraft: mr.isDraft
        )
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Log.info("[GitLab] Request: \(url.absoluteString)", category: Log.network)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            Task { @MainActor in
                RateLimitTracker.shared.track(response: httpResponse, provider: .gitlab)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                Log.error("[GitLab] API Error: \(httpResponse.statusCode)", category: Log.network)
                if httpResponse.statusCode == 401 { throw GitProviderError.unauthorized }
                if httpResponse.statusCode == 429 { throw GitProviderError.rateLimitExceeded }
                throw GitProviderError.apiError(statusCode: httpResponse.statusCode)
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            Log.error("[GitLab] Decoding Error", error: error, category: Log.network)
            throw error
        }
    }
}
