import XCTest
@testable import Unblockd

final class GitLabClientTests: XCTestCase {
    var client: GitLabClient!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = GitLabClient(session: session)
        client.setCredentials(username: "", token: "test-token")
    }

    override func tearDown() {
        client = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchPRs_RequestedChangesByMeIsWaiting() async throws {
        var reviewersEndpointCalls = 0

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let state = components?.queryItems?.first(where: { $0.name == "state" })?.value

            switch (url.path, state) {
            case ("/api/v4/user", _):
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests", "opened"):
                return (response, self.openMergeRequestsJSON(detailedMergeStatus: "requested_changes").data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests", "merged"):
                return (response, "[]".data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests/11/approvals", _):
                return (response, self.approvalsJSON.data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests/11/reviewers", _):
                reviewersEndpointCalls += 1
                return (response, self.reviewersJSON(state: "requested_changes").data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        let repo = GitRepository(
            id: "123",
            name: "repo",
            fullName: "group/repo",
            url: URL(string: "https://gitlab.com/group/repo"),
            provider: .gitlab
        )

        let items = try await client.fetchPRs(for: repo)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.state, .waiting)
        XCTAssertEqual(items.first?.hasChangesRequested, true)
        XCTAssertEqual(reviewersEndpointCalls, 1)
    }

    func testFetchPRs_SkipsReviewersEndpointOutsideRequestedChangesFlow() async throws {
        var reviewersEndpointCalls = 0

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let state = components?.queryItems?.first(where: { $0.name == "state" })?.value

            switch (url.path, state) {
            case ("/api/v4/user", _):
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests", "opened"):
                return (response, self.openMergeRequestsJSON(detailedMergeStatus: "mergeable").data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests", "merged"):
                return (response, "[]".data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests/11/approvals", _):
                return (response, self.approvalsJSON.data(using: .utf8)!)
            case ("/api/v4/projects/123/merge_requests/11/reviewers", _):
                reviewersEndpointCalls += 1
                return (response, self.reviewersJSON(state: "requested_changes").data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        let repo = GitRepository(
            id: "123",
            name: "repo",
            fullName: "group/repo",
            url: URL(string: "https://gitlab.com/group/repo"),
            provider: .gitlab
        )

        let items = try await client.fetchPRs(for: repo)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.state, .needsReview)
        XCTAssertEqual(reviewersEndpointCalls, 0)
    }

    private var userJSON: String {
        """
        {
            "id": 1,
            "username": "me",
            "name": "Me",
            "avatar_url": "https://example.com/me.png"
        }
        """
    }

    private var approvalsJSON: String {
        """
        {
            "id": 11,
            "iid": 11,
            "project_id": 123,
            "title": "MR",
            "state": "opened",
            "approvals_required": 1,
            "approvals_left": 1,
            "approved_by": []
        }
        """
    }

    private func reviewersJSON(state: String) -> String {
        """
        [
            {
                "state": "\(state)",
                "user": {
                    "id": 1,
                    "username": "me",
                    "name": "Me",
                    "avatar_url": "https://example.com/me.png"
                }
            }
        ]
        """
    }

    private func openMergeRequestsJSON(detailedMergeStatus: String) -> String {
        """
        [
            {
                "id": 11,
                "iid": 11,
                "project_id": 123,
                "title": "Fix issue",
                "description": "Desc",
                "state": "opened",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-02T12:00:00.000Z",
                "web_url": "https://gitlab.com/group/repo/-/merge_requests/11",
                "author": {
                    "id": 2,
                    "username": "author",
                    "name": "Author",
                    "avatar_url": null
                },
                "assignees": [],
                "reviewers": [
                    {
                        "id": 1,
                        "username": "me",
                        "name": "Me",
                        "avatar_url": "https://example.com/me.png"
                    }
                ],
                "user_notes_count": 0,
                "upvotes": 0,
                "downvotes": 0,
                "merge_status": "can_be_merged",
                "detailed_merge_status": "\(detailedMergeStatus)",
                "has_conflicts": false,
                "draft": false,
                "work_in_progress": false
            }
        ]
        """
    }
}
