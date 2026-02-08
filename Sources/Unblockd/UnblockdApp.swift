import SwiftUI

@main
struct UnblockdApp: App {
    @AppStorage(AppConfig.Keys.badgeCountMode) private var badgeCountMode: BadgeCountMode = .actionable
    @AppStorage(AppConfig.Keys.showMenuTooltip) private var showMenuTooltip = true
    @StateObject private var viewModel = DashboardViewModel()

    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
        } label: {
            HStack(spacing: 2) {
                if viewModel.isSleeping {
                    Image(systemName: "moon.zzz.fill")
                } else if viewModel.lastError != nil {
                    AppIcon(size: 18)
                    Text("!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red)
                } else {
                    AppIcon(size: 18)

                    let actionableCount = viewModel.items.filter { ($0.state == .needsReview || $0.state == .mergedNeedsReview) && !$0.isSnoozed }.count
                    let allCount = viewModel.items.count
                    let count = badgeCountMode == .actionable ? actionableCount : allCount

                    if count > 0 {
                        Text("\(count)")
                    } else if viewModel.isRefreshing || viewModel.lastUpdated == nil {
                        Text("...")
                            .font(.system(size: 12, weight: .bold))
                            .baselineOffset(1)
                    }
                }
            }
            .menuBarTooltip(showMenuTooltip ? viewModel.tooltipText : "")
        }
        .menuBarExtraStyle(.window)
    }
}
