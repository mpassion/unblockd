import Foundation

// MARK: - GitLab User
struct GitLabUser: Codable {
    let id: Int
    let username: String
    let name: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarUrl = "avatar_url"
    }
}

// MARK: - GitLab Project (Repository)
struct GitLabProject: Codable {
    let id: Int
    let name: String
    let pathWithNamespace: String
    let webUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case pathWithNamespace = "path_with_namespace"
        case webUrl = "web_url"
    }
}

// MARK: - GitLab Merge Request (PR)
struct GitLabMergeRequest: Codable {
    let id: Int
    let iid: Int
    let projectId: Int
    let title: String
    let description: String
    let state: String
    let createdAt: String
    let updatedAt: String
    let webUrl: String
    let author: GitLabUser
    let assignees: [GitLabUser]?
    let reviewers: [GitLabUser]?
    let userNotesCount: Int
    let upvotes: Int
    let downvotes: Int
    let mergeStatus: String
    let detailedMergeStatus: String?
    let hasConflicts: Bool

    // Additional fields for detail view
    let draft: Bool
    let workInProgress: Bool

    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, author, assignees, reviewers
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case webUrl = "web_url"
        case userNotesCount = "user_notes_count"
        case upvotes, downvotes
        case mergeStatus = "merge_status"
        case detailedMergeStatus = "detailed_merge_status"
        case hasConflicts = "has_conflicts"
        case draft
        case workInProgress = "work_in_progress"
    }

    var isDraft: Bool {
        return draft || workInProgress || title.lowercased().hasPrefix("draft:") || title.lowercased().hasPrefix("wip:")
    }
}

// MARK: - GitLab Approval State
struct GitLabApprovalState: Codable {
    let id: Int
    let iid: Int
    let projectId: Int
    let title: String
    let state: String
    let approvalsRequired: Int
    let approvalsLeft: Int
    let approvedBy: [GitLabApprover]

    enum CodingKeys: String, CodingKey {
        case id, iid, title, state
        case projectId = "project_id"
        case approvalsRequired = "approvals_required"
        case approvalsLeft = "approvals_left"
        case approvedBy = "approved_by"
    }
}

struct GitLabApprover: Codable {
    let user: GitLabUser
}

// MARK: - GitLab Reviewer State
struct GitLabReviewerStatus: Codable {
    let state: String
    let user: GitLabUser
}
