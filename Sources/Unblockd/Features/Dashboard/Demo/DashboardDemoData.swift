import Foundation

enum DashboardDemoData {
    private struct DemoPRSeed {
        let number: Int
        let title: String
        let author: String
        let state: PRItem.PRState
        let minutesAgo: Int
        let hasChangesRequested: Bool
        let approvalCount: Int
        let reviewerCount: Int
        let isDraft: Bool
    }

    static let repositories: [GitRepository] = [
        GitRepository(
            id: "bb-velocity-api",
            name: "velocity-api",
            fullName: "demo-team/velocity-api",
            url: URL(string: "https://example.com/demo-team/velocity-api"),
            provider: .bitbucket
        ),
        GitRepository(
            id: "bb-control-center",
            name: "control-center",
            fullName: "demo-team/control-center",
            url: URL(string: "https://example.com/demo-team/control-center"),
            provider: .bitbucket
        ),
        GitRepository(
            id: "gh-orbit-ios",
            name: "orbit-ios",
            fullName: "acme/orbit-ios",
            url: URL(string: "https://example.com/acme/orbit-ios"),
            provider: .github
        ),
        GitRepository(
            id: "gh-pulse-web",
            name: "pulse-web",
            fullName: "acme/pulse-web",
            url: URL(string: "https://example.com/acme/pulse-web"),
            provider: .github
        ),
        GitRepository(
            id: "gl-forge-auth",
            name: "forge-auth",
            fullName: "platform/forge-auth",
            url: URL(string: "https://example.com/platform/forge-auth"),
            provider: .gitlab
        ),
        GitRepository(
            id: "gl-docs-portal",
            name: "docs-portal",
            fullName: "platform/docs-portal",
            url: URL(string: "https://example.com/platform/docs-portal"),
            provider: .gitlab
        )
    ]

    static let monitoredRepositories: [MonitoredRepository] = repositories.map { repo in
        let parts = repo.fullName.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        let workspace = parts.first.map(String.init) ?? ""
        let slug = parts.count > 1 ? String(parts[1]) : repo.name
        return MonitoredRepository(
            id: repo.id,
            slug: slug,
            workspace: workspace,
            name: repo.name,
            fullName: repo.fullName,
            provider: repo.provider
        )
    }

    static func searchRepositories(query: String, provider: ProviderType) -> [GitRepository] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredByProvider = repositories.filter { $0.provider == provider }

        guard !normalizedQuery.isEmpty else {
            return filteredByProvider
        }

        return filteredByProvider.filter {
            $0.name.lowercased().contains(normalizedQuery) ||
            $0.fullName.lowercased().contains(normalizedQuery)
        }
    }

    static func items(for monitoredRepositories: [MonitoredRepository], now: Date = Date()) -> [PRItem] {
        let itemsByRepo = demoItemsByRepository(now: now)
        let allItems = itemsByRepo.values
            .flatMap { $0 }
            .sorted { $0.lastActivity > $1.lastActivity }

        if monitoredRepositories.isEmpty {
            return allItems
        }

        let monitoredKeys = Set(monitoredRepositories.map {
            "\($0.resolvedProvider.rawValue):\($0.id)"
        })

        var selectedItems: [PRItem] = []
        for key in monitoredKeys {
            selectedItems.append(contentsOf: itemsByRepo[key] ?? [])
        }
        if selectedItems.isEmpty {
            return allItems
        }

        return selectedItems.sorted { $0.lastActivity > $1.lastActivity }
    }

    private static func demoItemsByRepository(now: Date) -> [String: [PRItem]] {
        let byFullName = Dictionary(uniqueKeysWithValues: repositories.map { ($0.fullName, $0) })
        guard
            let velocityAPI = byFullName["demo-team/velocity-api"],
            let controlCenter = byFullName["demo-team/control-center"],
            let orbitIOS = byFullName["acme/orbit-ios"],
            let pulseWeb = byFullName["acme/pulse-web"],
            let forgeAuth = byFullName["platform/forge-auth"],
            let docsPortal = byFullName["platform/docs-portal"]
        else {
            return [:]
        }

        return [
            velocityAPI.monitoringKey: [
                makePR(
                    repo: velocityAPI,
                    seed: DemoPRSeed(
                        number: 241,
                        title: "feat(review-routing): prioritize urgent queues first",
                        author: "Maya Brooks",
                        state: .needsReview,
                        minutesAgo: 18,
                        hasChangesRequested: false,
                        approvalCount: 0,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                ),
                makePR(
                    repo: velocityAPI,
                    seed: DemoPRSeed(
                        number: 236,
                        title: "refactor(cache): isolate stale key cleanup",
                        author: "Ethan Cole",
                        state: .team,
                        minutesAgo: 210,
                        hasChangesRequested: false,
                        approvalCount: 0,
                        reviewerCount: 1,
                        isDraft: false
                    ),
                    now: now
                )
            ],
            controlCenter.monitoringKey: [
                makePR(
                    repo: controlCenter,
                    seed: DemoPRSeed(
                        number: 89,
                        title: "fix(notifications): avoid duplicate desktop alerts",
                        author: "Iris Novak",
                        state: .waiting,
                        minutesAgo: 90,
                        hasChangesRequested: false,
                        approvalCount: 2,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                ),
                makePR(
                    repo: controlCenter,
                    seed: DemoPRSeed(
                        number: 84,
                        title: "chore(ui): improve compact card spacing",
                        author: "Alex Kim",
                        state: .stale,
                        minutesAgo: 1560,
                        hasChangesRequested: false,
                        approvalCount: 0,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                )
            ],
            orbitIOS.monitoringKey: [
                makePR(
                    repo: orbitIOS,
                    seed: DemoPRSeed(
                        number: 517,
                        title: "feat(sync): support offline draft restore",
                        author: "Noah Patel",
                        state: .needsReview,
                        minutesAgo: 42,
                        hasChangesRequested: false,
                        approvalCount: 0,
                        reviewerCount: 3,
                        isDraft: true
                    ),
                    now: now
                ),
                makePR(
                    repo: orbitIOS,
                    seed: DemoPRSeed(
                        number: 509,
                        title: "fix(search): debounce heavy repository filtering",
                        author: "Lena Scott",
                        state: .mergedNeedsReview,
                        minutesAgo: 1320,
                        hasChangesRequested: false,
                        approvalCount: 2,
                        reviewerCount: 3,
                        isDraft: false
                    ),
                    now: now
                )
            ],
            pulseWeb.monitoringKey: [
                makePR(
                    repo: pulseWeb,
                    seed: DemoPRSeed(
                        number: 133,
                        title: "feat(metrics): add review cycle duration chart",
                        author: "Owen Reed",
                        state: .team,
                        minutesAgo: 360,
                        hasChangesRequested: false,
                        approvalCount: 1,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                ),
                makePR(
                    repo: pulseWeb,
                    seed: DemoPRSeed(
                        number: 129,
                        title: "fix(onboarding): handle empty workspace state",
                        author: "Grace Lin",
                        state: .waiting,
                        minutesAgo: 40,
                        hasChangesRequested: true,
                        approvalCount: 0,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                )
            ],
            forgeAuth.monitoringKey: [
                makePR(
                    repo: forgeAuth,
                    seed: DemoPRSeed(
                        number: 77,
                        title: "feat(security): rotate token fingerprint secrets",
                        author: "Ravi Shah",
                        state: .stale,
                        minutesAgo: 720,
                        hasChangesRequested: false,
                        approvalCount: 1,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                ),
                makePR(
                    repo: forgeAuth,
                    seed: DemoPRSeed(
                        number: 72,
                        title: "fix(auth): avoid stale refresh token usage",
                        author: "Mila Park",
                        state: .needsReview,
                        minutesAgo: 24,
                        hasChangesRequested: false,
                        approvalCount: 1,
                        reviewerCount: 3,
                        isDraft: false
                    ),
                    now: now
                )
            ],
            docsPortal.monitoringKey: [
                makePR(
                    repo: docsPortal,
                    seed: DemoPRSeed(
                        number: 21,
                        title: "docs(playbook): add release rollback checklist",
                        author: "Dylan Ross",
                        state: .team,
                        minutesAgo: 540,
                        hasChangesRequested: false,
                        approvalCount: 0,
                        reviewerCount: 1,
                        isDraft: false
                    ),
                    now: now
                ),
                makePR(
                    repo: docsPortal,
                    seed: DemoPRSeed(
                        number: 19,
                        title: "docs(install): clarify Homebrew tap bootstrap flow",
                        author: "Sara Bell",
                        state: .mergedNeedsReview,
                        minutesAgo: 2040,
                        hasChangesRequested: false,
                        approvalCount: 1,
                        reviewerCount: 2,
                        isDraft: false
                    ),
                    now: now
                )
            ]
        ]
    }

    private static func makePR(
        repo: GitRepository,
        seed: DemoPRSeed,
        now: Date
    ) -> PRItem {
        return PRItem(
            id: "demo:\(repo.provider.rawValue):\(repo.id):\(seed.number)",
            title: seed.title,
            repository: repo.name,
            author: seed.author,
            avatarURL: nil,
            lastActivity: now.addingTimeInterval(TimeInterval(-seed.minutesAgo * 60)),
            state: seed.state,
            hasChangesRequested: seed.hasChangesRequested,
            approvalCount: seed.approvalCount,
            reviewerCount: seed.reviewerCount,
            url: URL(string: "https://example.com/\(repo.fullName)/pull/\(seed.number)"),
            isSnoozed: false,
            isDraft: seed.isDraft
        )
    }
}
