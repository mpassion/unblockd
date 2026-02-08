import Foundation

struct PRRulesEngine {
    let currentUserUUID: String

    // MARK: - Public API

    func classify(pr: BitbucketPR, isDraft: Bool = false) -> PRItem.PRState {
        // Handle drafts
        if isDraft {
            if isAuthor(of: pr) {
                return .stale // My draft
            }
            return .team // Others' drafts are low priority
        }

        if pr.state == "MERGED" {
             // Check if I should have reviewed this
             if let reviewState = determineReviewStatus(for: pr), reviewState == .needsReview {
                 return .mergedNeedsReview
             }
             return .team // Or ignore? For now team/other.
        }

        if isAuthor(of: pr) {
            return .stale // "My PRs" section
        }

        if let reviewState = determineReviewStatus(for: pr) {
            return reviewState
        }

        return .team // "Other / Team" section
    }

    // MARK: - Private Helpers

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

        // I am assigned, now check if I've already acted on it
        if hasactedOn(pr) {
            return .waiting
        }

        // Assigned and pending action
        return .needsReview
    }

    private func hasactedOn(_ pr: BitbucketPR) -> Bool {
        guard let participants = pr.participants else { return false }
        let myUUID = normalize(currentUserUUID)

        // Find my participation record
        if let myStat = participants.first(where: { p in
            guard let id = p.user.uuid else { return false }
            return normalize(id) == myUUID
        }) {
            // "Acted" means Approved OR Requested Changes
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
