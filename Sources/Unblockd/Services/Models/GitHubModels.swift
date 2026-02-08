import Foundation

struct GitHubUser: Codable {
    let id: Int
    let login: String
    let name: String?
    let avatar_url: String
}

struct GitHubRepository: Codable {
    let id: Int
    let name: String
    let full_name: String
    let html_url: String
    let owner: GitHubUser
    let permissions: GitHubPermissions?
}

struct GitHubPermissions: Codable {
    let admin: Bool
    let push: Bool
    let pull: Bool
}

struct GitHubPR: Codable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let html_url: String
    let user: GitHubUser // Author
    let created_at: String
    let updated_at: String
    let draft: Bool?

    // Details (might be partial in search)
    let requested_reviewers: [GitHubUser]?
    let assignees: [GitHubUser]?

    // Links for detail fetching if needed
    let url: String

    // Merged info
    let merged_at: String?
}

// Search response
struct GitHubSearchResponse<T: Codable>: Codable {
    let total_count: Int
    let items: [T]
}

enum GitHubReviewState: String, Codable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"
}

struct GitHubReview: Codable {
    let id: Int
    let user: GitHubUser
    let state: GitHubReviewState
    let submitted_at: String?
}
