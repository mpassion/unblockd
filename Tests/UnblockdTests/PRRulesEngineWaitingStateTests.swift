import XCTest
@testable import Unblockd

final class PRRulesEngineWaitingStateTests: XCTestCase {

    func testClassifyWaitingWhenChangesRequestedByAssignedReviewer() throws {
        let myUUID = "my-id"
        let engine = PRRulesEngine(currentUserUUID: myUUID)

        let pr = try makePR(
            authorUUID: "other-id",
            reviewerUUID: myUUID,
            participantApproved: false,
            participantState: "changes_requested"
        )

        XCTAssertEqual(engine.classify(pr: pr), .waiting)
    }

    private func makePR(
        authorUUID: String,
        reviewerUUID: String,
        participantApproved: Bool,
        participantState: String
    ) throws -> BitbucketPR {
        let json = """
        {
            "id": 123,
            "title": "Mock PR",
            "state": "OPEN",
            "author": { "display_name": "Author", "uuid": "\(authorUUID)" },
            "destination": {
                "repository": { "name": "Repo", "full_name": "owner/repo", "uuid": "{repo-uuid}" }
            },
            "updated_on": "2024-01-01T12:00:00.000000+00:00",
            "comment_count": 0,
            "reviewers": [
                { "display_name": "Me", "uuid": "\(reviewerUUID)" }
            ],
            "participants": [
                {
                    "user": { "display_name": "Me", "uuid": "\(reviewerUUID)" },
                    "approved": \(participantApproved),
                    "state": "\(participantState)"
                }
            ],
            "links": null
        }
        """

        return try JSONDecoder().decode(BitbucketPR.self, from: Data(json.utf8))
    }
}
