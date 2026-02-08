import Foundation

enum AppConfig {
    enum Keys {
        static let bitbucketUsername = "bitbucket_username"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let startHour = "startHour"
        static let endHour = "endHour"
        static let showToReview = "showToReview"
        static let showWaiting = "showWaiting"
        static let showMyPRs = "showMyPRs"
        static let showTeam = "showTeam"
        static let showMerged = "showMerged"
        static let showSnoozed = "showSnoozed"
        static let snoozedPRs = "snoozed_prs"
        static let monitoredRepos = "com.unblockd.monitoredRepos"
        static let activeDays = "activeDays"
        static let mergeLookbackDays = "mergeLookbackDays"
        static let rateLimitBitbucket = "rateLimitBitbucket"
        static let rateLimitGitHub = "rateLimitGitHub"
        static let rateLimitGitLab = "rateLimitGitLab"
        static let gitlabToken = "gitlab_token"
        static let gitlabHost = "gitlab_host" // For future self-hosted support
        static let badgeCountMode = "badgeCountMode"
        static let showMenuTooltip = "showMenuTooltip"
    }

    enum Defaults {
        static let refreshInterval = 60
        static let minimumRefreshInterval = 15
        static let startHour = 9
        static let endHour = 17
        static let activeDays: [Int] = [2, 3, 4, 5, 6] // Monday to Friday (Calendar.Component.weekday)
        static let mergeLookbackDays = 7
        static let rateLimitBitbucket = 1000
        static let rateLimitGitHub = 5000
        static let rateLimitGitLab = 2000
        static let wakeUpDelaySeconds: Double = 5.0
    }

    enum UIConstants {
        static let availableRefreshIntervals = [15, 30, 60, 120]
    }

    enum Limits {
        static let searchResultLimit = 50 // Default Page Size for repos
        static let githubSearchLimit = 100
        static let githubReviewFetchConcurrency = 6
    }

    enum Timeouts {
        static let bitbucketPagingDelayNanoseconds: UInt64 = 200_000_000 // 0.2s
    }
}

enum BadgeCountMode: String, CaseIterable, Identifiable {
    case actionable
    case all

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .actionable: return "Actionable only"
        case .all: return "All visible sections"
        }
    }
}
