import Foundation

struct PRItem: Identifiable, Hashable {
    let id: String
    let title: String
    let repository: String
    let author: String
    let avatarURL: URL?
    let lastActivity: Date
    var state: PRState
    let hasChangesRequested: Bool
    let approvalCount: Int
    let reviewerCount: Int
    let url: URL?
    var isSnoozed: Bool = false
    let isDraft: Bool

    enum PRState: String {
        case needsReview = "Needs Review"
        case waiting = "Waiting"
        case stale = "Stale"
        case team = "Team"
        case mergedNeedsReview = "Merged"
        case unknown
    }

    var initials: String {
        let parts = author.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return "\(first.prefix(2))".uppercased()
        }
        return "??"
    }
}

extension PRItem {
    init(from apiPR: BitbucketPR) {
        self.id = "\(apiPR.destination.repository.full_name)/\(apiPR.id)"
        self.title = apiPR.title
        self.repository = apiPR.destination.repository.name
        self.author = apiPR.author.display_name

        if let href = apiPR.author.links?.avatar?.href {
            self.avatarURL = URL(string: href)
        } else {
            self.avatarURL = nil
        }

        let formatter = ISO8601DateFormatter()
        // Bitbucket format: 2023-10-25T12:00:00.000000+00:00 (Fractional seconds handled by options)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.lastActivity = formatter.date(from: apiPR.updated_on) ?? Date()

        self.state = .needsReview

        if let participants = apiPR.participants {
            self.hasChangesRequested = participants.contains { $0.state == .changes_requested }
            self.approvalCount = participants.filter { $0.approved }.count
        } else {
            self.hasChangesRequested = false
            self.approvalCount = 0
        }

        self.reviewerCount = apiPR.reviewers?.count ?? 0

        if let href = apiPR.links?.html?.href {
            self.url = URL(string: href)
        } else {
            self.url = nil
        }

        self.isDraft = apiPR.draft ?? false
    }
}

extension PRItem {
    static let mocks: [PRItem] = [
        PRItem(
            id: "1",
            title: "Fix login crash on iOS 16",
            repository: "mobile-app",
            author: "Jane Doe",
            avatarURL: nil,
            lastActivity: Date().addingTimeInterval(-3600),
            state: .needsReview,
            hasChangesRequested: false,
            approvalCount: 1,
            reviewerCount: 2,
            url: URL(string: "https://bitbucket.org"),
            isDraft: false
        ),
        PRItem(
            id: "2",
            title: "Refactor payment gateway",
            repository: "backend-api",
            author: "John Smith",
            avatarURL: nil,
            lastActivity: Date().addingTimeInterval(-172800 - 3600),
            state: .stale,
            hasChangesRequested: true,
            approvalCount: 0,
            reviewerCount: 1,
            url: URL(string: "https://bitbucket.org"),
            isDraft: false
        ),
        PRItem(
            id: "3",
            title: "Update README.md",
            repository: "docs",
            author: "Mike",
            avatarURL: nil,
            lastActivity: Date().addingTimeInterval(-300),
            state: .waiting,
            hasChangesRequested: false,
            approvalCount: 2,
            reviewerCount: 2,
            url: URL(string: "https://bitbucket.org"),
            isDraft: false
        )
    ]
}
