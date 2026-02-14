import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    @AppStorage(AppConfig.Keys.showToReview) private var showToReview = true
    @AppStorage(AppConfig.Keys.showWaiting) private var showWaiting = true
    @AppStorage(AppConfig.Keys.showMyPRs) private var showMyPRs = true
    @AppStorage(AppConfig.Keys.showTeam) private var showTeam = true
    @AppStorage(AppConfig.Keys.mergeLookbackDays) private var mergeLookbackDays = AppConfig.Defaults.mergeLookbackDays
    @AppStorage(AppConfig.Keys.badgeCountMode) private var badgeCountMode: BadgeCountMode = .actionable

    var items: [PRItem] { viewModel.items }

    @ObservedObject private var rateTracker = RateLimitTracker.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        AppIcon(size: 24)
                            .foregroundStyle(Color.ubPrimary)
                        Text(Strings.Dashboard.appName)
                            .font(.system(size: 14, weight: .bold))
                            .tracking(-0.5)
                    }

                    Spacer()

                    let actionableCount = items.filter { ($0.state == .needsReview || $0.state == .mergedNeedsReview) && !$0.isSnoozed }.count
                    let allCount = items.count

                    let displayCount = badgeCountMode == .actionable ? actionableCount : allCount
                    let displayText = badgeCountMode == .actionable ? Strings.Dashboard.itemsNeedReview(displayCount) : Strings.Dashboard.itemsCount(displayCount)

                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                        Text(displayText)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.ubPrimary.opacity(0.1))
                    .foregroundStyle(Color.ubPrimary)
                    .cornerRadius(12)

                    Spacer()

                    HStack(spacing: 0) {
                        Menu {
                            NavigationLink {
                                SettingsView(viewModel: viewModel, repoService: viewModel.repoService)
                            } label: {
                                Text("Preferences...")
                            }

                            Divider()

                            Button("Quit Unblockd") {
                                NSApplication.shared.terminate(nil)
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.ubHeaderBg)

                Divider()
                    .opacity(0.5)

                ScrollView {
                    VStack(spacing: 16) {

                        if let error = viewModel.lastError {
                            CompactErrorBanner(error: error) {
                                NavigationLink {
                                    SettingsView(viewModel: viewModel, repoService: viewModel.repoService)
                                } label: {
                                    Text("Fix")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.9))
                                        .foregroundStyle(Color.ubStatusRed)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if showToReview {
                            PRGroup(title: Strings.Dashboard.Groups.toReview, items: items.filter { $0.state == .needsReview && !$0.isSnoozed }, color: .ubStatusOrange, viewModel: viewModel)
                        }

                        let lookbackDate = Calendar.current.date(byAdding: .day, value: -Int(mergeLookbackDays), to: Date()) ?? Date()
                        let mergedItems = items.filter {
                             $0.state == .mergedNeedsReview &&
                             !$0.isSnoozed &&
                             $0.lastActivity >= lookbackDate
                        }
                        if !mergedItems.isEmpty {
                            PRGroup(title: Strings.Dashboard.Groups.merged, items: mergedItems, color: .ubStatusPurple, viewModel: viewModel)
                        }
                        if showWaiting {
                            PRGroup(title: Strings.Dashboard.Groups.waiting, items: items.filter { $0.state == .waiting && !$0.isSnoozed }, color: .ubStatusBlue, inactive: true, viewModel: viewModel)
                        }
                        if showMyPRs {
                            PRGroup(title: Strings.Dashboard.Groups.myPRs, items: items.filter { $0.state == .stale && !$0.isSnoozed }, color: .ubPrimary, viewModel: viewModel)
                        }
                        if showTeam {
                            PRGroup(title: Strings.Dashboard.Groups.other, items: items.filter { $0.state == .team && !$0.isSnoozed }, color: .secondary, inactive: true, viewModel: viewModel)
                        }

                        let snoozed = items.filter { $0.isSnoozed }
                        if !snoozed.isEmpty {
                            PRGroup(title: Strings.Dashboard.Groups.snoozed, items: snoozed, color: .secondary, inactive: true, viewModel: viewModel)
                        }

                        if items.isEmpty && viewModel.lastError == nil {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.secondary.opacity(0.5))
                                Text(Strings.Dashboard.allCaughtUp)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .ubBackground()

                HStack {
                    if rateTracker.isLimited {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.octagon.fill")
                            if let reset = rateTracker.resetTime {
                                Text(Strings.Dashboard.Status.limitReached + " \(Strings.Dashboard.Status.resetsAt(reset.formatted(date: .omitted, time: .shortened)))")
                            } else {
                                Text(Strings.Dashboard.Status.rateLimitReached)
                            }
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.ubStatusRed)
                     } else if let error = viewModel.lastError {
                          HStack(spacing: 4) {
                              if case .networkRequestFailed(_, let p) = error, let provider = p {
                                  providerIcon(for: provider)
                              } else if case .authenticationFailed(let p) = error, let provider = p {
                                  providerIcon(for: provider)
                              } else if case .rateLimitExceeded(_, let p) = error, let provider = p {
                                  providerIcon(for: provider)
                              } else if case .multipleAuthErrors = error {
                                   Image(systemName: "lock.slash.fill")
                              } else {
                                  Image(systemName: "exclamationmark.triangle.fill")
                              }

                              if case .authenticationFailed = error {
                                  Text(Strings.Dashboard.Status.authError)
                              } else if case .multipleAuthErrors = error {
                                  Text("Auth Errors")
                              } else if case .networkRequestFailed = error {
                                  Text(Strings.Dashboard.Status.connectionError)
                              } else {
                                  Text(Strings.Dashboard.Status.error)
                              }

                              if let date = viewModel.lastUpdated {
                                  Text("•")
                                      .opacity(0.4)
                                  Text(Strings.Dashboard.Status.dataPrefix + " \(date.formatted(date: .omitted, time: .shortened))")
                                      .opacity(0.8)
                              }
                          }
                          .font(.system(size: 9, weight: .bold))
                          .foregroundStyle(Color.ubStatusRed)
                          .help(error.localizedDescription)
                    } else {
                        HStack(spacing: 4) {
                            if rateTracker.warningLevel != .none {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }

                            Image(systemName: "arrow.clockwise")
                            if let date = viewModel.lastUpdated {
                                Text(Strings.Dashboard.Status.updated + ": \(date.formatted(date: .omitted, time: .shortened))")
                            } else {
                                Text(Strings.Dashboard.Status.updatedNever)
                            }
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        Task { await viewModel.refresh(force: true) }
                    }, label: {
                        HStack(spacing: 4) {
                            Text(viewModel.isRefreshing ? Strings.Dashboard.Button.refreshing : (viewModel.lastError != nil ? Strings.Dashboard.Button.retry : Strings.Dashboard.Button.refresh))
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                                .animation(viewModel.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(viewModel.lastError != nil ? Color.ubStatusRed : Color.ubPrimary)

                        .cornerRadius(6)
                    })
                    .disabled(viewModel.isRefreshing)
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.ubHeaderBg)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .top)
            }
            .toolbar(.hidden, for: .windowToolbar)
        }
        .frame(width: 340, height: 500)
    }
    @ViewBuilder
    private func providerIcon(for provider: ProviderType) -> some View {
        switch provider {
        case .github:
            Image(systemName: "cat.circle.fill")
        case .bitbucket:
            Image(systemName: "bitcoinsign.circle.fill")
        case .gitlab:
            Image(systemName: "externaldrive.fill.badge.checkmark")
        }
    }
}

struct HeaderButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
                .frame(width: 32, height: 32)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct PRGroup: View {
    let title: String
    let items: [PRItem]
    let color: Color
    var inactive: Bool = false

    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.openURL) var openURL

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(title) (\(items.count))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(inactive ? Color.secondary : Color.secondary)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 1)
                }
                .opacity(inactive ? 0.6 : 1.0)

                ForEach(items) { item in
                    Button(action: {
                        if let url = item.url {
                            openURL(url)
                        }
                    }, label: {
                        ModernPRRow(item: item, themeColor: color)
                            .contentShape(Rectangle())
                    })
                    .buttonStyle(.plain)
                    .focusable(false)
                    .opacity(inactive ? 0.7 : 1.0)
                    .grayscale(inactive ? 0.5 : 0)
                    .contextMenu {
                        Section {
                            if item.isSnoozed {
                                Button {
                                    viewModel.unsnooze(prID: item.id)
                                } label: {
                                    Label(Strings.Dashboard.ContextMenu.unsnooze, systemImage: "bell.fill")
                                }
                            } else {
                                Button {
                                    viewModel.snooze(prID: item.id, duration: 7200)
                                } label: {
                                    Label(Strings.Dashboard.ContextMenu.snooze2h, systemImage: "clock")
                                }
                                Button {
                                    viewModel.snooze(prID: item.id, duration: 14400)
                                } label: {
                                    Label(Strings.Dashboard.ContextMenu.snooze4h, systemImage: "clock.arrow.circlepath")
                                }
                                Button {
                                    viewModel.snoozeUntilTomorrow(prID: item.id)
                                } label: {
                                    Label(Strings.Dashboard.ContextMenu.snoozeTomorrow, systemImage: "moon.zzz")
                                }
                            }
                        }

                        if let url = item.url {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                            } label: {
                                Label(Strings.Dashboard.ContextMenu.copyLink, systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ModernPRRow: View {
    let item: PRItem
    let themeColor: Color

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.ubCard)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    // Draw accent as part of the same rounded border for clean anti-aliased corners.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(themeColor.opacity(0.95), lineWidth: 2)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: 6)
                                Spacer(minLength: 0)
                            }
                        )
                }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal")
                            Text(item.repository)
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        Text(item.lastActivity.formatted(.relative(presentation: .named).locale(Locale(identifier: "en_US"))))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }

                    if item.isDraft {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.and.outline")
                            Text("DRAFT")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondary)
                        .padding(2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    }

                    if item.hasChangesRequested {
                         HStack(spacing: 4) {
                             Image(systemName: "exclamationmark.triangle.fill")
                             Text("CHANGES REQUESTED")
                         }
                         .font(.system(size: 9.5, weight: .bold))
                         .foregroundStyle(Color.ubStatusOrange)
                         .padding(.horizontal, 6)
                         .padding(.vertical, 2)
                         .background(Color.ubStatusOrange.opacity(0.1))
                         .cornerRadius(4)
                    } else if item.approvalCount > 0 {
                         HStack(spacing: 4) {
                             Image(systemName: "checkmark.circle.fill")
                             let total = max(item.reviewerCount, item.approvalCount)
                             Text("APPROVED (\(item.approvalCount)/\(total))")
                         }
                         .font(.system(size: 9.5, weight: .bold))
                         .foregroundStyle(Color.ubStatusGreen)
                         .padding(.horizontal, 6)
                         .padding(.vertical, 2)
                         .background(Color.ubStatusGreen.opacity(0.1))
                         .cornerRadius(4)
                    } else if themeColor == .ubStatusGreen {
                         HStack(spacing: 4) {
                             Image(systemName: "arrow.triangle.pull")
                             let total = max(item.reviewerCount, item.approvalCount)
                             Text("OPEN (\(item.approvalCount)/\(total))")
                         }
                         .font(.system(size: 9.5, weight: .bold))
                         .foregroundStyle(Color.secondary)
                         .padding(.horizontal, 6)
                         .padding(.vertical, 2)
                         .background(Color.secondary.opacity(0.1))
                         .cornerRadius(4)
                    }
                }
                .padding(.leading, 10)

                Spacer()

                HStack(spacing: -8) {
                    AvatarView(url: item.avatarURL, initials: item.initials)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
                .shadow(radius: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 56)
        .onHover { isHovering = $0 }
    }
}
