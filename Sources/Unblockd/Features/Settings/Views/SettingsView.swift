import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var repoService: RepositoryService
    @StateObject private var settingsViewModel: SettingsViewModel

    @AppStorage(AppConfig.Keys.showToReview) private var showToReview = true
    @AppStorage(AppConfig.Keys.showWaiting) private var showWaiting = true
    @AppStorage(AppConfig.Keys.showMyPRs) private var showMyPRs = true
    @AppStorage(AppConfig.Keys.showTeam) private var showTeam = true
    @AppStorage(AppConfig.Keys.showMerged) private var showMerged = true
    @AppStorage(AppConfig.Keys.showSnoozed) private var showSnoozed = false
    @AppStorage(AppConfig.Keys.refreshIntervalMinutes) private var refreshIntervalMinutes = AppConfig.Defaults.refreshInterval
    @AppStorage(AppConfig.Keys.startHour) private var startHour = AppConfig.Defaults.startHour
    @AppStorage(AppConfig.Keys.endHour) private var endHour = AppConfig.Defaults.endHour
    @AppStorage(AppConfig.Keys.mergeLookbackDays) private var mergeLookbackDays = AppConfig.Defaults.mergeLookbackDays

    @State private var activeDays: [Int] = AppConfig.Defaults.activeDays
    @StateObject private var launchService = LaunchAtLoginService()

    init(viewModel: DashboardViewModel, repoService: RepositoryService) {
        self.viewModel = viewModel
        self.repoService = repoService
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(dashboardViewModel: viewModel))
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button(action: {
                    dismiss()
                }, label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.primary.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                })
                .buttonStyle(.plain)
                .help("Back")

                Spacer()

                Text("Preferences")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()
                Spacer().frame(width: 28)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.ubHeaderBg)

            Divider().opacity(0.5)

            // MARK: Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    BehaviorSection(launchService: launchService, refreshIntervalMinutes: $refreshIntervalMinutes)

                    ScheduleSection(activeDays: $activeDays, startHour: $startHour, endHour: $endHour, onUpdate: { viewModel.startPolling() })

                    MenuContentSection(
                        showToReview: $showToReview,
                        showWaiting: $showWaiting,
                        showMyPRs: $showMyPRs,
                        showTeam: $showTeam,
                        showMerged: $showMerged,
                        showSnoozed: $showSnoozed,
                        mergeLookbackDays: $mergeLookbackDays
                    )

                    AccountSection(
                        selectedProvider: $settingsViewModel.selectedProvider,
                        username: $settingsViewModel.username,
                        token: $settingsViewModel.token,
                        isConnecting: settingsViewModel.isConnecting,
                        connectionError: settingsViewModel.connectionError,
                        connectedUsername: settingsViewModel.connectedUsername,
                        connectAction: settingsViewModel.connectToProvider
                    )

                    DiscoverySection(
                        serverQuery: $settingsViewModel.serverQuery,
                        selectedProvider: settingsViewModel.selectedProvider,
                        isSearching: settingsViewModel.isSearching,
                        availableRepos: settingsViewModel.availableRepos,
                        viewModel: viewModel,
                        searchAction: settingsViewModel.searchRepositories
                    )
                    ActiveReposSection(repoService: repoService)

                    Spacer().frame(height: 20)

                    VStack(spacing: 4) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                            .resizable()
                            .frame(width: 32, height: 32)
                            .opacity(0.8)

                        Text("Unblockd")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.primary.opacity(0.8))

                        VStack(spacing: 1) {
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            Text("© 2026")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)
                }
                .padding(20)
            }
            .ubBackground()

            rateLimitWarning
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            settingsViewModel.refreshCredentials()
            loadActiveDays()
            normalizeRefreshInterval()
        }
        .onChange(of: settingsViewModel.selectedProvider) { _ in
            settingsViewModel.handleProviderChange()
        }
        .onChange(of: refreshIntervalMinutes) { _ in viewModel.startPolling() }
        .onChange(of: startHour) { _ in viewModel.startPolling() }
        .onChange(of: endHour) { _ in viewModel.startPolling() }
        .onChange(of: showToReview) { _ in viewModel.applyFilters() }
        .onChange(of: showWaiting) { _ in viewModel.applyFilters() }
        .onChange(of: showMyPRs) { _ in viewModel.applyFilters() }
        .onChange(of: showTeam) { _ in viewModel.applyFilters() }
        .onChange(of: showMerged) { _ in viewModel.applyFilters() }
        .onChange(of: showSnoozed) { _ in viewModel.applyFilters() }
        .onChange(of: mergeLookbackDays) { _ in viewModel.startPolling() }
    }

    @ObservedObject private var rateTracker = RateLimitTracker.shared

    private var rateLimitWarning: some View {
        Group {
            if rateTracker.warningLevel != .none || rateTracker.isLimited {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: rateTracker.isLimited ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(rateTracker.isLimited ? .ubStatusRed : .orange)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(rateTracker.isLimited ? "RATE LIMIT REACHED" : "HIGH API USAGE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(rateTracker.isLimited ? .ubStatusRed : .orange)

                            Text("\(rateTracker.callsThisHour)/\(rateTracker.totalLimit) calls. Resets \(rateTracker.resetTime?.formatted(date: .omitted, time: .shortened) ?? "Now")")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.ubHeaderBg)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .top)
            }
        }
    }

    private func loadActiveDays() {
        if let saved = UserDefaults.standard.array(forKey: AppConfig.Keys.activeDays) as? [Int] {
            activeDays = saved
        }
    }

    private func normalizeRefreshInterval() {
        let minInterval = AppConfig.Defaults.minimumRefreshInterval
        if refreshIntervalMinutes < minInterval {
            refreshIntervalMinutes = minInterval
            UserDefaults.standard.set(minInterval, forKey: AppConfig.Keys.refreshIntervalMinutes)
            viewModel.startPolling()
        }
    }
}

// MARK: - Sections

struct BehaviorSection: View {
    let launchService: LaunchAtLoginService
    @Binding var refreshIntervalMinutes: Int
    @AppStorage(AppConfig.Keys.showMenuTooltip) private var showMenuTooltip = true
    @AppStorage(AppConfig.Keys.badgeCountMode) private var badgeCountMode = BadgeCountMode.actionable.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Behavior")
            VStack(spacing: 0) {
                ToggleRow(title: "Launch at Login", isOn: Binding(
                    get: { launchService.isEnabled },
                    set: { _ in launchService.toggle() }
                ), icon: "power")

                Divider().padding(.leading, 40)

                ToggleRow(title: "Show Menu Bar Tooltip", isOn: $showMenuTooltip, icon: "info.circle")

                Divider().padding(.leading, 40)

                HStack {
                    Image(systemName: "app.badge") // Icon for Badge
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24)
                    Text("Badge Count")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { BadgeCountMode(rawValue: badgeCountMode) ?? .actionable },
                        set: { badgeCountMode = $0.rawValue }
                    )) {
                        ForEach(BadgeCountMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: 140)
                    .labelsHidden()
                }
                .padding(12)

                Divider().padding(.leading, 40)

                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24)
                    Text("Refresh Interval")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("", selection: $refreshIntervalMinutes) {
                        ForEach(AppConfig.UIConstants.availableRefreshIntervals, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .frame(width: 100)
                    .labelsHidden()
                }
                .padding(12)
            }
            .ubCard()
        }
    }
}

struct ScheduleSection: View {
    @Binding var activeDays: [Int]
    @Binding var startHour: Int
    @Binding var endHour: Int
    var onUpdate: () -> Void
    @State private var hoveredDay: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Schedule")
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 24)
                        Text("Active Days")
                            .font(.system(size: 14))
                        Spacer()
                        HStack(spacing: 8) {
                            Button("Workdays") {
                                activeDays = [2, 3, 4, 5, 6]
                                UserDefaults.standard.set(activeDays, forKey: AppConfig.Keys.activeDays)
                                onUpdate()
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.ubPrimary)
                            .buttonStyle(.plain)

                            Text("|").font(.caption2).foregroundColor(.secondary.opacity(0.3))

                            Button("All") {
                                activeDays = [1, 2, 3, 4, 5, 6, 7]
                                UserDefaults.standard.set(activeDays, forKey: AppConfig.Keys.activeDays)
                                onUpdate()
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.ubPrimary)
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Button(action: { toggleDay(day) }, label: {
                                Text(Calendar.current.shortWeekdayName(for: day))
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(activeDays.contains(day) ? Color.ubPrimary : Color.primary.opacity(0.05))
                                    .foregroundColor(activeDays.contains(day) ? .white : .primary)
                                    .cornerRadius(6)
                            })
                            .buttonStyle(.plain)
                            .help(Calendar.current.fullWeekdayName(for: day))
                            .onHover { isHovering in hoveredDay = isHovering ? day : nil }
                        }
                    }
                }
                .padding(12)

                Divider().padding(.leading, 12)

                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24)
                    Text("Active Hours")
                        .font(.system(size: 14))
                    Spacer()
                    HStack(spacing: 12) {
                        Picker("", selection: $startHour) {
                            ForEach(0...23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        Text("-").foregroundStyle(Color.secondary)
                        Picker("", selection: $endHour) {
                            ForEach(0...23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                    }
                }
                .padding(12)
            }
            .ubCard()
        }
    }

    private func toggleDay(_ day: Int) {
        if activeDays.contains(day) {
            activeDays.removeAll { $0 == day }
        } else {
            activeDays.append(day)
            activeDays.sort()
        }
        UserDefaults.standard.set(activeDays, forKey: AppConfig.Keys.activeDays)
        onUpdate()
    }
}

struct MenuContentSection: View {
    @Binding var showToReview: Bool
    @Binding var showWaiting: Bool
    @Binding var showMyPRs: Bool
    @Binding var showTeam: Bool
    @Binding var showMerged: Bool
    @Binding var showSnoozed: Bool
    @Binding var mergeLookbackDays: Int

    @State private var showDescriptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionLabel(title: "Menu Content")
                Spacer()
                Button(action: { withAnimation { showDescriptions.toggle() } }, label: {
                    Image(systemName: showDescriptions ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(showDescriptions ? Color.ubPrimary : Color.secondary)
                })
                .buttonStyle(.plain)
                .help("Toggle descriptions")
            }
            VStack(spacing: 0) {
                ToggleRow(
                    title: Strings.Dashboard.Groups.toReview,
                    isOn: $showToReview,
                    icon: "exclamationmark.circle.fill",
                    description: Strings.Dashboard.Tooltips.toReview,
                    showDescription: showDescriptions
                )
                Divider().padding(.leading, 40)
                ToggleRow(
                    title: Strings.Dashboard.Groups.showMerged,
                    isOn: $showMerged,
                    icon: "exclamationmark.triangle",
                    description: Strings.Dashboard.Tooltips.merged,
                    showDescription: showDescriptions
                )
                if showMerged {
                    HStack {
                         Spacer().frame(width: 38)
                         Text("Lookback: \(mergeLookbackDays) days")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                         Spacer()
                         Stepper("", value: $mergeLookbackDays, in: 1...30)
                             .labelsHidden()
                             .controlSize(.mini)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    Divider().padding(.leading, 40)
                } else {
                    Divider().padding(.leading, 40)
                }
                ToggleRow(title: Strings.Dashboard.Groups.waiting, isOn: $showWaiting, icon: "hourglass", description: Strings.Dashboard.Tooltips.waiting, showDescription: showDescriptions)
                Divider().padding(.leading, 40)
                ToggleRow(title: Strings.Dashboard.Groups.myPRs, isOn: $showMyPRs, icon: "person.fill", description: Strings.Dashboard.Tooltips.myPRs, showDescription: showDescriptions)
                Divider().padding(.leading, 40)
                ToggleRow(title: Strings.Dashboard.Groups.showTeam, isOn: $showTeam, icon: "person.2.fill", description: Strings.Dashboard.Tooltips.other, showDescription: showDescriptions)
                Divider().padding(.leading, 40)
                ToggleRow(title: Strings.Dashboard.Groups.showSnoozed, isOn: $showSnoozed, icon: "moon.zzz.fill", description: Strings.Dashboard.Tooltips.snoozed, showDescription: showDescriptions)
            }
            .ubCard()
        }
    }
}

struct AccountSection: View {
    @Binding var selectedProvider: ProviderType
    @Binding var username: String
    @Binding var token: String
    let isConnecting: Bool
    let connectionError: String?
    let connectedUsername: String?
    let connectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionLabel(title: "Account")
                Spacer()
                Picker("", selection: $selectedProvider) {
                    ForEach(ProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            VStack(spacing: 0) {
                if selectedProvider == .bitbucket {
                    HStack {
                        Image(systemName: "person").foregroundStyle(Color.secondary).frame(width: 24)
                        TextField("Bitbucket Username", text: $username).textFieldStyle(.plain)
                    }.padding(12)
                    Divider().padding(.leading, 40)
                }

                HStack {
                    Image(systemName: "key").foregroundStyle(Color.secondary).frame(width: 24)
                    SecureField(selectedProvider == .bitbucket ? "App Password" : "Personal Access Token", text: $token)
                        .textFieldStyle(.plain)
                }.padding(12)

                Divider()
                Button(action: connectAction) {
                    HStack {
                        if isConnecting { ProgressView().controlSize(.small).padding(.trailing, 4) }
                        Text(isConnecting ? "Connecting..." : "Connect & Save").fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.ubPrimary).foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(token.isEmpty || isConnecting)
                .opacity((token.isEmpty || isConnecting) ? 0.6 : 1.0)
            }
            .ubCard()
            if let error = connectionError {
                if !RateLimitTracker.shared.isLimited {
                    Text(error).font(.caption).foregroundStyle(Color.ubStatusRed).padding(.horizontal, 4)
                }
            } else if let connectedUser = connectedUsername {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Connected as \(connectedUser)")
                }
                .font(.caption)
                .foregroundStyle(Color.ubStatusGreen)
                .padding(.horizontal, 4)
            }
        }
    }
}

struct DiscoverySection: View {
    @Binding var serverQuery: String
    let selectedProvider: ProviderType
    let isSearching: Bool
    let availableRepos: [GitRepository]
    let viewModel: DashboardViewModel
    let searchAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Browse \(selectedProvider.displayName) Repositories")
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.secondary).frame(width: 24)
                    TextField("Search repositories...", text: $serverQuery).textFieldStyle(.plain).onSubmit(searchAction)
                    if !serverQuery.isEmpty {
                        Button(action: searchAction) {
                            Text("Search").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.ubPrimary.opacity(0.1)).foregroundColor(.ubPrimary).cornerRadius(4)
                        }.buttonStyle(.plain)
                    }
                }.padding(12)
                if !availableRepos.isEmpty {
                    Divider()
                    LazyVStack(spacing: 0) {
                        ForEach(availableRepos, id: \.id) { repo in
                            RepoRow(repo: repo, isMonitored: viewModel.isMonitored(repo: repo)) {
                                viewModel.toggleRepo(repo)
                            }
                            if repo.id != availableRepos.last?.id { Divider().padding(.leading, 40) }
                        }
                    }
                } else if isSearching {
                    Divider()
                    ProgressView().controlSize(.small).padding(20).frame(maxWidth: .infinity)
                }
            }
            .ubCard()
        }
    }
}

struct ActiveReposSection: View {
    @ObservedObject var repoService: RepositoryService

    @State private var expandedProviders: Set<ProviderType> = []

    var body: some View {
        let repos = repoService.monitoredRepositories
        if !repos.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(title: "Active Repositories")

                VStack(spacing: 0) {
                    ForEach(ProviderType.allCases, id: \.self) { provider in
                        let providerRepos = repos.filter { $0.resolvedProvider == provider }

                        if !providerRepos.isEmpty {
                            RepoGroup(
                                provider: provider,
                                repos: providerRepos,
                                isExpanded: Binding(
                                    get: { expandedProviders.contains(provider) },
                                    set: { isExpanded in
                            if isExpanded { expandedProviders.insert(provider) } else { expandedProviders.remove(provider) }
                        }
                                ),
                                repoService: repoService
                            )

                            if provider != ProviderType.allCases.last &&
                                repos.contains(where: {
                                    $0.resolvedProvider != provider &&
                                    ProviderType.allCases.firstIndex(of: $0.resolvedProvider)! > ProviderType.allCases.firstIndex(of: provider)!
                                }) {
                                Divider()
                            }
                        }
                    }
                }
                .ubCard()
            }
        }
    }
}

struct RepoGroup: View {
    let provider: ProviderType
    let repos: [MonitoredRepository]
    @Binding var isExpanded: Bool
    @ObservedObject var repoService: RepositoryService

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }, label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)

                    Text(provider.displayName).font(.system(size: 13, weight: .medium))
                    Text("(\(repos.count))").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            })
            .buttonStyle(.plain)

            if isExpanded {
                if repos.isEmpty {
                    Text("(no repositories)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 44)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(repos) { repo in
                            Divider().padding(.leading, 12)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.name).font(.system(size: 13, weight: .medium))
                                    Text(repo.fullName).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) { repoService.remove(id: repo.id, provider: repo.resolvedProvider) } label: {
                                    Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.ubStatusRed.opacity(0.8))
                                }.buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }
}

struct RepoRow: View {
    let repo: GitRepository
    let isMonitored: Bool
    let action: () -> Void

    var body: some View {
         HStack {
             VStack(alignment: .leading, spacing: 2) {
                 HStack(spacing: 4) {
                     Text(repo.name)
                         .font(.system(size: 14, weight: .medium))
                 }
                 Text(repo.fullName)
                     .font(.caption)
                     .foregroundStyle(.secondary)
             }
             Spacer()
             Button(action: action) {
                 Image(systemName: isMonitored ? "checkmark.circle.fill" : "circle")
                     .font(.title2)
                     .foregroundStyle(isMonitored ? Color.ubStatusBlue : Color.secondary.opacity(0.3))
             }
             .buttonStyle(.plain)
         }
         .padding(12)
         .background(isMonitored ? Color.ubStatusBlue.opacity(0.1) : Color.clear)
    }
}

struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.secondary)
            .tracking(1.0)
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    var description: String?
    var showDescription: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14))
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            if showDescription, let description = description {
                HStack(spacing: 0) {
                    Spacer().frame(width: 36)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(12)
    }
}
