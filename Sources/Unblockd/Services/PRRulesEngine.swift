import Foundation

struct PRRulesEngine {
    let currentUserUUID: String

    func classify(pr: BitbucketPR, isDraft: Bool = false) -> PRItem.PRState {
        if isDraft {
            if isAuthor(of: pr) {
                return .stale
            }
            return .team
        }

        if pr.state == "MERGED" {
            if let reviewState = determineReviewStatus(for: pr), reviewState == .needsReview {
                return .mergedNeedsReview
            }
            return .team
        }

        if isAuthor(of: pr) {
            return .stale
        }

        if let reviewState = determineReviewStatus(for: pr) {
            return reviewState
        }

        return .team
    }

    private func isAuthor(of pr: BitbucketPR) -> Bool {
        guard let authorUUID = pr.author.uuid else { return false }
        return normalize(authorUUID) == normalize(currentUserUUID)
    }

    private func determineReviewStatus(for pr: BitbucketPR) -> PRItem.PRState? {
        guard let reviewers = pr.reviewers else { return nil }

        let myUUID = normalize(currentUserUUID)
        let isAssigned = reviewers.contains { reviewer in
            guard let id = reviewer.uuid else { return false }
            return normalize(id) == myUUID
        }

        guard isAssigned else { return nil }

        if hasActedOn(pr) {
            return .waiting
        }

        return .needsReview
    }

    private func hasActedOn(_ pr: BitbucketPR) -> Bool {
        guard let participants = pr.participants else { return false }
        let myUUID = normalize(currentUserUUID)

        if let myStat = participants.first(where: { p in
            guard let id = p.user.uuid else { return false }
            return normalize(id) == myUUID
        }) {
            return myStat.approved || myStat.state == .changes_requested
        }

        return false
    }

    /// Normalizes UUIDs by stripping braces and lowercasing for consistent comparison
    private func normalize(_ uuid: String) -> String {
        return uuid
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .lowercased()
    }
}
