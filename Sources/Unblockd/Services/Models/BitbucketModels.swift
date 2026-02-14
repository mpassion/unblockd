import Foundation

struct BitbucketPagedResponse<T: Decodable>: Decodable {
    let size: Int?
    let page: Int?
    let next: String?
    let values: [T]
}

struct BitbucketLinks: Decodable {
    let html: BitbucketLink?
    let avatar: BitbucketLink?
}

struct BitbucketLink: Decodable {
    let href: String
}

struct BitbucketRepository: Decodable, Identifiable {
    let uuid: String
    let name: String
    let full_name: String
    let is_private: Bool
    let links: BitbucketLinks?

    var id: String { uuid }
}

struct BitbucketPR: Decodable, Identifiable {
    let id: Int
    let title: String
    let state: String
    let author: BitbucketUserWrapper
    let destination: BitbucketDestination
    let updated_on: String
    let comment_count: Int
    let reviewers: [BitbucketUserWrapper]?
    let participants: [BitbucketParticipant]?
    let links: BitbucketLinks?
    let draft: Bool? // Bitbucket Cloud API supports draft PRs

    struct BitbucketUserWrapper: Decodable {
        let display_name: String
        let uuid: String?
        let links: BitbucketLinks?
    }

    struct BitbucketDestination: Decodable {
        let repository: BitbucketRepoWrapper
    }

    struct BitbucketRepoWrapper: Decodable {
        let name: String
        let full_name: String
        let uuid: String
    }

    struct BitbucketParticipant: Decodable {
        let user: BitbucketUserWrapper
        let approved: Bool
        let state: ParticipantState?

        enum ParticipantState: String, Decodable {
            case approved
            case changes_requested
            case null
        }
    }
}

struct BitbucketUser: Decodable {
    let display_name: String
    let uuid: String
    let account_id: String?
    let nickname: String?
    let links: BitbucketLinks?
}
