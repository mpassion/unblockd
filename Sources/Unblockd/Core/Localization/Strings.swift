import Foundation

enum Strings {
    enum Dashboard {
        static let appName = "Unblockd"
        static func itemsCount(_ count: Int) -> String { "\(count) items" }
        static func itemsNeedReview(_ count: Int) -> String { "\(count) need review" }
        static let allCaughtUp = "All caught up"

        enum Groups {
            static let toReview = "To Review"
            static let waiting = "Waiting"
            static let myPRs = "My PRs"
            static let other = "Other / Team"
            static let showTeam = "Other / Team"
            static let showMerged = "Merged Without My Review"
            static let showSnoozed = "Show Snoozed"
            static let snoozed = "Snoozed"
            static let merged = "Merged Without My Review"
        }

        enum Tooltips {
            static let toReview = "PRs where you're assigned as reviewer and haven't acted yet."
            static let waiting = "Open PRs where you've already reviewed. Waiting for others."
            static let myPRs = "Your own Pull Requests."
            static let other = "Other open PRs in monitored repositories."
            static let merged = "Merged PRs where your review was still pending."
            static let snoozed = "Temporarily hidden Pull Requests."
        }

        enum Status {
            static let limitReached = "LIMIT REACHED"
            static let rateLimitReached = "RATE LIMIT REACHED"
            static let error = "ERROR"
            static let authError = "AUTH ERROR"
            static let connectionError = "CONNECTION"
            static let updated = "UPDATED"
            static let updatedNever = "UPDATED: NEVER"
            static let refreshing = "Refreshing..."
            static let dataPrefix = "DATA:"
            static func resetsAt(_ time: String) -> String { "(Resets \(time))" }
        }

        enum StatusBar {
            static let `default` = "Unblockd"
            static func sleepingUntil(_ time: String) -> String { "Sleeping until \(time)" }
        }

        enum Button {
            static let refresh = "Refresh"
            static let refreshing = "Refreshing..."
            static let retry = "Retry"
        }

        enum ContextMenu {
            static let unsnooze = "Unsnooze"
            static let snooze2h = "Snooze 2h"
            static let snooze4h = "Snooze 4h"
            static let snoozeTomorrow = "Snooze until tomorrow"
            static let copyLink = "Copy Link"
        }
    }

    enum Settings {
        static let title = "Settings"
    }
}
