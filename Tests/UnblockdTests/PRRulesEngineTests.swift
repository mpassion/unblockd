import XCTest
@testable import Unblockd

final class PRRulesEngineTests: XCTestCase {

    func testClassifyMyPR() throws {
        let myUUID = "{user-uuid}"
        let engine = PRRulesEngine(currentUserUUID: myUUID)

        let pr = makePR(authorUUID: myUUID, reviewers: [], participants: [])
        XCTAssertEqual(engine.classify(pr: pr), .stale)
    }

    func testClassifyNeedsReview() throws {
        let myUUID = "my-id"
        let engine = PRRulesEngine(currentUserUUID: myUUID)

        let pr = makePR(
            authorUUID: "other-id",
            reviewers: [.init(display_name: "Me", uuid: myUUID, links: nil)],
            participants: []
        )

        XCTAssertEqual(engine.classify(pr: pr), .needsReview)
    }

    func testClassifyWaitingApproved() throws {
        let myUUID = "my-id"
        let engine = PRRulesEngine(currentUserUUID: myUUID)

        let pr = makePR(
            authorUUID: "other-id",
            reviewers: [.init(display_name: "Me", uuid: myUUID, links: nil)],
            participants: [
                .init(user: .init(display_name: "Me", uuid: myUUID, links: nil), approved: true, state: .approved)
            ]
        )

        XCTAssertEqual(engine.classify(pr: pr), .waiting)
    }

    private func makePR(authorUUID: String, reviewers: [BitbucketPR.BitbucketUserWrapper]?, participants: [BitbucketPR.BitbucketParticipant]?) -> BitbucketPR {
        let reviewersJSON: String
        if let revs = reviewers {
            let items = revs.map { "{\"display_name\": \"\($0.display_name)\", \"uuid\": \"\($0.uuid ?? "")\"}" }
            reviewersJSON = "[\(items.joined(separator: ","))]"
        } else {
            reviewersJSON = "null"
        }

        let participantsJSON: String
        if let parts = participants {
            let items = parts.map { part in
                """
                {
                    "user": {"display_name": "\(part.user.display_name)", "uuid": "\(part.user.uuid ?? "")"},
                    "approved": \(part.approved),
                    "state": \(part.state == nil ? "null" : "\"\(part.state!)\"")
                }
                """
            }
            participantsJSON = "[\(items.joined(separator: ","))]"
        } else {
            participantsJSON = "null"
        }

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
            "reviewers": \(reviewersJSON),
            "participants": \(participantsJSON),
            "links": null
        }
        """

        let data = json.data(using: .utf8)!
        return try! JSONDecoder().decode(BitbucketPR.self, from: data)
    }
}
