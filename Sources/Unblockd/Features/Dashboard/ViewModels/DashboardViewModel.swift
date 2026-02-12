import Foundation
import Combine
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    enum LifecycleMode {
        case active
        case manual

        var shouldAutoRefreshOnInit: Bool {
            self == .active
        }

        var shouldStartPolling: Bool {
            self == .active
        }
    }

    @Published var items: [PRItem] = []
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?

    @Published var tooltipText: String = Strings.Dashboard.StatusBar.default

    @Published var isSleeping = false

    let repoService: RepositoryService
    private var providers: [ProviderType: any GitProvider] = [:]
    private let demoMode: Bool

    private var pollingTask: Task<Void, Never>?
    private var repositoriesRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var snoozedItems: [String: Date] = [:]

    private var lastRawItems: [PRItem] = []
    private struct TokenSnapshot {
        let bbUsername: String
        let bbToken: String
        let ghToken: String
        let glToken: String
    }
    private static let demoTooltip = "Demo mode: using mock repositories and PRs"

    init(
        repoService: RepositoryService = RepositoryService(),
        lifecycle: LifecycleMode = .active,
        demoMode: Bool = false
    ) {
        self.repoService = repoService
        self.demoMode = demoMode

        self.providers[.bitbucket] = BitbucketClient()
        self.providers[.github] = GitHubClient()
        self.providers[.gitlab] = GitLabClient()

        if demoMode {
            repoService.monitoredRepositories = DashboardDemoData.monitoredRepositories
        }

        if let data = UserDefaults.standard.dictionary(forKey: AppConfig.Keys.snoozedPRs) as? [String: Date] {
            let now = Date()
            self.snoozedItems = data.filter { $0.value > now }
        }

        TokenManager.shared.$cachedTokens
            .receive(on: RunLoop.main)
            .sink { [weak self] tokens in
                self?.updateCredentials(using: tokens)
            }
            .store(in: &cancellables)

        updateCredentials(using: TokenManager.shared.cachedTokens)

        self.checkActiveHours()

        repoService.$monitoredRepositories
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Log.info("📦 Repositories changed, triggering auto-refresh...", category: Log.data)
                self?.scheduleRepositoriesRefresh()
            }
            .store(in: &cancellables)

        if lifecycle.shouldAutoRefreshOnInit {
            Task { await refresh(force: true) }
        }

        if lifecycle.shouldStartPolling {
            startPolling()

            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
                .sink { [weak self] _ in
                    self?.handleWake()
                }
                .store(in: &cancellables)
        }
    }

    private func handleWake() {
        Log.info("☀️ System woke up. Checking schedule and refreshing...", category: Log.data)
        Task {
            let delay = UInt64(AppConfig.Defaults.wakeUpDelaySeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)

            self.checkActiveHours()
            if !self.isSleeping {
                Log.info("🔄 Wake-up refresh triggered...", category: Log.data)
                await self.refresh(force: true)
            } else {
                 Log.info("💤 Woke up but outside active hours. Skipping refresh.", category: Log.data)
            }
        }
    }

    private func updateCredentials(using tokens: [ProviderType: String]) {
        if let bbProvider = providers[.bitbucket] {
            let user = UserDefaults.standard.string(forKey: AppConfig.Keys.bitbucketUsername) ?? ""
            let token = tokens[.bitbucket] ?? ""
            bbProvider.setCredentials(username: user, token: token)
        }

        if let ghProvider = providers[.github] {
             let token = tokens[.github] ?? ""
             ghProvider.setCredentials(username: "", token: token)
        }

        if let glProvider = providers[.gitlab] {
            let token = tokens[.gitlab] ?? ""
            glProvider.setCredentials(username: "", token: token)
        }
    }

    deinit {
        repositoriesRefreshTask?.cancel()
        Log.info("🗑️ [Lifecycle] DashboardViewModel deinit", category: Log.general)
    }

    // MARK: - API Actions

    func searchRepositories(query: String, provider: ProviderType) async throws -> [GitRepository] {
        if demoMode {
            return DashboardDemoData.searchRepositories(query: query, provider: provider)
        }
        guard let p = providers[provider] else { return [] }
        return try await p.fetchRepositories(query: query)
    }

    func toggleRepo(_ repo: GitRepository) {
        if repoService.isMonitored(id: repo.id, provider: repo.provider) {
            repoService.remove(id: repo.id, provider: repo.provider)
        } else {
            repoService.add(repository: repo)
        }
    }

    func isMonitored(repo: GitRepository) -> Bool {
        return repoService.isMonitored(id: repo.id, provider: repo.provider)
    }

    // MARK: - Snooze Logic

    func snooze(prID: String, duration: TimeInterval) {
        let expiration = Date().addingTimeInterval(duration)
        snoozedItems[prID] = expiration
        saveSnoozedItems()
        withAnimation { applyFilters() }
    }

    func unsnooze(prID: String) {
        snoozedItems.removeValue(forKey: prID)
        saveSnoozedItems()
        withAnimation { applyFilters() }
    }

    func snoozeUntilTomorrow(prID: String) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let nextMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            let duration = nextMorning.timeIntervalSinceNow
            snooze(prID: prID, duration: duration)
        } else {
            snooze(prID: prID, duration: 24 * 60 * 60)
        }
    }

    private func saveSnoozedItems() {
        UserDefaults.standard.set(snoozedItems, forKey: AppConfig.Keys.snoozedPRs)
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            self?.performInitialPollCheck()

            while !Task.isCancelled {
                guard let self = self else {
                    Log.warning("⚠️ [Lifecycle] DashboardViewModel deallocated during polling loop", category: Log.general)
                    return
                }

                let minutes = UserDefaults.standard.integer(forKey: AppConfig.Keys.refreshIntervalMinutes)
                let configuredInterval = minutes > 0 ? minutes : AppConfig.Defaults.refreshInterval
                let interval = max(configuredInterval, AppConfig.Defaults.minimumRefreshInterval)
                let nanoseconds = UInt64(interval * 60) * 1_000_000_000

                Log.info("⏳ Next refresh in \(interval) min...", category: Log.data)

                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { break }

                await self.performPollCycle()
            }
        }
    }

    private func performInitialPollCheck() {
        checkActiveHours()
        if !isSleeping {
            Log.info("🔄 Settings changed/Poller started - Refreshing immediately...", category: Log.data)
            Task { await refresh(force: false) }
        }
    }

    private func performPollCycle() async {
        checkActiveHours()
        if !isSleeping {
            Log.info("🔄 Background polling triggered...", category: Log.data)
            await refresh(force: true)
        } else {
            Log.info("💤 Skipping refresh (Outside active hours)", category: Log.data)
        }
    }

    private func scheduleRepositoriesRefresh() {
        repositoriesRefreshTask?.cancel()
        repositoriesRefreshTask = Task { [weak self] in
            // Let UI update first and coalesce quick add/remove bursts from settings.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh(force: true)
        }
    }

    private func checkActiveHours() {
        if demoMode {
            self.isSleeping = false
            self.updateTooltipText()
            return
        }

        let startHour = UserDefaults.standard.object(forKey: AppConfig.Keys.startHour) as? Int ?? AppConfig.Defaults.startHour
        let endHour = UserDefaults.standard.object(forKey: AppConfig.Keys.endHour) as? Int ?? AppConfig.Defaults.endHour

        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)

        let activeDays: [Int] = (UserDefaults.standard.array(forKey: AppConfig.Keys.activeDays) as? [Int]) ?? AppConfig.Defaults.activeDays
        let isTodayActive = activeDays.contains(currentWeekday)

        var isActiveTime = false
        if startHour <= endHour {
            isActiveTime = (currentHour >= startHour && currentHour < endHour)
        } else {
            isActiveTime = (currentHour >= startHour || currentHour < endHour)
        }

        self.isSleeping = !(isTodayActive && isActiveTime)
        self.updateTooltipText()
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private func updateTooltipText() {
        if demoMode {
            self.tooltipText = Self.demoTooltip
            return
        }

        if isSleeping {
            let startHour = UserDefaults.standard.object(forKey: AppConfig.Keys.startHour) as? Int ?? AppConfig.Defaults.startHour
            let activeDays: [Int] = (UserDefaults.standard.array(forKey: AppConfig.Keys.activeDays) as? [Int]) ?? AppConfig.Defaults.activeDays

            let calendar = Calendar.current
            let now = Date()

            var currentCheck = now
            var resolvedText = Strings.Dashboard.StatusBar.sleepingUntil("\(String(format: "%02d", startHour)):00")

            for _ in 0...7 {
                if let candidate = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: currentCheck) {
                    let activeCandidate = candidate > now ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)!
                    let weekday = calendar.component(.weekday, from: activeCandidate)

                    if activeDays.contains(weekday) {
                        let formatter = Self.tooltipDateFormatter

                        if calendar.isDateInToday(activeCandidate) {
                            formatter.dateFormat = "HH:mm"
                        } else if calendar.isDateInTomorrow(activeCandidate) {
                            resolvedText = Strings.Dashboard.StatusBar.sleepingUntil("Tomorrow, \(String(format: "%02d", startHour)):00")
                            break
                        } else {
                            formatter.dateFormat = "EEEE, HH:mm"
                        }
                        resolvedText = Strings.Dashboard.StatusBar.sleepingUntil(formatter.string(from: activeCandidate))
                        break
                    }
                    currentCheck = calendar.date(byAdding: .day, value: 1, to: activeCandidate)!
                } else { break }
            }
            self.tooltipText = resolvedText
        } else if let error = lastError {
            self.tooltipText = error.localizedDescription
        } else {
            self.tooltipText = Strings.Dashboard.StatusBar.default
        }
    }

    @Published var lastError: DashboardError?

    func refresh(force: Bool = false) async {
        checkActiveHours()

        if !force, let last = lastUpdated, Date().timeIntervalSince(last) < 30 {
            Log.info("⏳ Skipping refresh (Data is fresh)", category: Log.data)
            return
        }

        isRefreshing = true
        self.lastError = nil
        defer { isRefreshing = false }

        if demoMode {
            self.lastRawItems = DashboardDemoData.items(for: repoService.monitoredRepositories)
            applyFilters()
            self.lastUpdated = Date()
            updateTooltipText()
            Log.info("✅ Demo refresh complete. \(self.items.count) visible PRs.", category: Log.data)
            return
        }

        let monitoredRepos = repoService.monitoredRepositories
        guard !monitoredRepos.isEmpty else {
            self.lastRawItems = []
            self.items = []
            return
        }

        updateCredentials(using: TokenManager.shared.cachedTokens)
        let tokenSnapshot = Self.currentTokenSnapshot()
        let reposByProvider = Dictionary(grouping: monitoredRepos, by: \.resolvedProvider)

        let (allPRs, encounteredErrors) = await fetchAllPRs(reposByProvider: reposByProvider, tokenSnapshot: tokenSnapshot)
        self.lastError = resolveRefreshError(encounteredErrors, allPRs: allPRs)

        if !allPRs.isEmpty || encounteredErrors.isEmpty {
            self.lastRawItems = allPRs
            applyFilters()
        } else {
            Log.warning("⚠️ Total failure. Keeping stale data.", category: Log.data)
        }

        self.lastUpdated = Date()
        updateTooltipText()

        if encounteredErrors.isEmpty {
            Log.info("✅ Refresh complete. \(self.items.count) visible PRs. (Total: \(allPRs.count))", category: Log.data)
        } else {
            Log.warning("⚠️ Refresh partial/failed. Errors: \(encounteredErrors.count)", category: Log.data)
        }
    }

    private func fetchAllPRs(
        reposByProvider: [ProviderType: [MonitoredRepository]],
        tokenSnapshot: TokenSnapshot
    ) async -> ([PRItem], [DashboardError]) {
        var allPRs: [PRItem] = []
        var encounteredErrors: [DashboardError] = []

        await withTaskGroup(of: [Result<[PRItem], DashboardError>].self) { group in
            for (providerType, providerRepos) in reposByProvider {
                let snapshot = tokenSnapshot
                group.addTask {
                    let provider = Self.makeProvider(for: providerType, tokens: snapshot)
                    var results: [Result<[PRItem], DashboardError>] = []

                    for repo in providerRepos {
                        do {
                            let items = try await provider.fetchPRs(for: repo.toGitRepository())
                            results.append(.success(items))
                        } catch {
                            if (error as? URLError)?.code == .cancelled { continue }
                            results.append(.failure(Self.mapDashboardError(error, provider: providerType)))
                        }
                    }

                    return results
                }
            }

            for await providerResults in group {
                for result in providerResults {
                    switch result {
                    case .success(let prs):
                        allPRs.append(contentsOf: prs)
                    case .failure(let error):
                        Log.error("Repository fetch failed", error: error, category: Log.network)
                        encounteredErrors.append(error)
                    }
                }
            }
        }

        return (allPRs, encounteredErrors)
    }

    private func resolveRefreshError(_ encounteredErrors: [DashboardError], allPRs: [PRItem]) -> DashboardError? {
        guard !encounteredErrors.isEmpty else {
            return nil
        }

        let authProviders = encounteredErrors.compactMap { error -> ProviderType? in
            if case .authenticationFailed(let p) = error { return p }
            return nil
        }
        let uniqueAuthProviders = Array(Set(authProviders.compactMap { $0 })).sorted(by: { $0.displayName < $1.displayName })

        if uniqueAuthProviders.count > 1 {
            return .multipleAuthErrors(uniqueAuthProviders)
        }

        if let criticalError = encounteredErrors.first(where: {
            if case .authenticationFailed = $0 { return true }
            if case .rateLimitExceeded = $0 { return true }
            return false
        }) {
            return criticalError
        }

        return allPRs.isEmpty ? encounteredErrors.first : nil
    }

    private static func currentTokenSnapshot() -> TokenSnapshot {
        return TokenSnapshot(
            bbUsername: UserDefaults.standard.string(forKey: AppConfig.Keys.bitbucketUsername) ?? "",
            bbToken: TokenManager.shared.getToken(for: .bitbucket) ?? "",
            ghToken: TokenManager.shared.getToken(for: .github) ?? "",
            glToken: TokenManager.shared.getToken(for: .gitlab) ?? ""
        )
    }

    nonisolated private static func makeProvider(for providerType: ProviderType, tokens: TokenSnapshot) -> any GitProvider {
        let username = providerType == .bitbucket ? tokens.bbUsername : ""
        let token: String
        switch providerType {
        case .bitbucket: token = tokens.bbToken
        case .github: token = tokens.ghToken
        case .gitlab: token = tokens.glToken
        }
        return GitProviderFactory.makeProvider(for: providerType, username: username, token: token)
    }

    nonisolated private static func mapDashboardError(_ error: Error, provider: ProviderType) -> DashboardError {
        guard let providerError = error as? GitProviderError else {
            return .networkRequestFailed(error.localizedDescription, provider: provider)
        }

        switch providerError {
        case .unauthorized:
            return .authenticationFailed(provider: provider)
        case .rateLimitExceeded:
            return .rateLimitExceeded(reset: nil, provider: provider)
        default:
            return .networkRequestFailed(providerError.localizedDescription, provider: provider)
        }
    }

    func applyFilters() {
        cleanupExpiredSnoozes()

        Log.debug("applyFilters raw items: \(lastRawItems.count)", category: Log.data)

        let defaults = UserDefaults.standard
        let showSnoozed = defaults.object(forKey: AppConfig.Keys.showSnoozed) as? Bool ?? false
        let showToReview = defaults.object(forKey: AppConfig.Keys.showToReview) as? Bool ?? true
        let showWaiting = defaults.object(forKey: AppConfig.Keys.showWaiting) as? Bool ?? true
        let showMyPRs = defaults.object(forKey: AppConfig.Keys.showMyPRs) as? Bool ?? true
        let showTeam = defaults.object(forKey: AppConfig.Keys.showTeam) as? Bool ?? true
        let showMerged = defaults.object(forKey: AppConfig.Keys.showMerged) as? Bool ?? true

        Log.debug(
            "applyFilters flags: toReview=\(showToReview) waiting=\(showWaiting) myPRs=\(showMyPRs) team=\(showTeam) merged=\(showMerged) snoozed=\(showSnoozed)",
            category: Log.data
        )

        self.items = lastRawItems.compactMap { pr -> PRItem? in
            var item = pr

            if self.snoozedItems[item.id] != nil {
                item.isSnoozed = true
                if !showSnoozed { return nil }
            }

            switch item.state {
            case .needsReview: if !showToReview { return nil }
            case .waiting: if !showWaiting { return nil }
            case .stale: if !showMyPRs { return nil }
            case .team: if !showTeam { return nil }
            case .mergedNeedsReview: if !showMerged { return nil }
            case .unknown: return nil
            }

            return item
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }

    private func cleanupExpiredSnoozes() {
        let now = Date()
        let initialCount = snoozedItems.count
        snoozedItems = snoozedItems.filter { $0.value > now }
        if snoozedItems.count != initialCount { saveSnoozedItems() }
    }
}
