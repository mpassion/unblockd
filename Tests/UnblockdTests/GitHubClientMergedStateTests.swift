import XCTest
@testable import Unblockd

final class GitHubClientMergedStateTests: XCTestCase {
    var client: GitHubClient!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = GitHubClient(session: session)
        client.setCredentials(username: "", token: "test-token")
    }

    override func tearDown() {
        client = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchPRs_MergedNotAssignedToMeIsTeam() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch (url.path, url.query ?? "") {
            case ("/user", _):
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls", let query) where query.contains("state=open"):
                return (response, "[]".data(using: .utf8)!)
            case ("/search/issues", _):
                return (response, self.mergedSearchJSON(assignedToMe: false).data(using: .utf8)!)
            case ("/repos/owner/repo/pulls/201/reviews", _):
                return (response, "[]".data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        let items = try await client.fetchPRs(for: repo)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.state, .team)
    }

    func testFetchPRs_MergedAssignedToMeWithoutActionIsMergedNeedsReview() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch (url.path, url.query ?? "") {
            case ("/user", _):
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls", let query) where query.contains("state=open"):
                return (response, "[]".data(using: .utf8)!)
            case ("/search/issues", _):
                return (response, self.mergedSearchJSON(assignedToMe: true).data(using: .utf8)!)
            case ("/repos/owner/repo/pulls/201/reviews", _):
                return (response, "[]".data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        let items = try await client.fetchPRs(for: repo)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.state, .mergedNeedsReview)
    }

    private var repo: GitRepository {
        GitRepository(
            id: "repo-1",
            name: "repo",
            fullName: "owner/repo",
            url: URL(string: "https://github.com/owner/repo"),
            provider: .github
        )
    }

    private var userJSON: String {
        """
        {
            "id": 1,
            "login": "me",
            "name": "Me",
            "avatar_url": "https://example.com/me.png"
        }
        """
    }

    private func mergedSearchJSON(assignedToMe: Bool) -> String {
        let reviewers = assignedToMe ? """
        [{
            "id": 1,
            "login": "me",
            "name": "Me",
            "avatar_url": "https://example.com/me.png"
        }]
        """ : "[]"

        return """
        {
            "total_count": 1,
            "items": [
                {
                    "id": 2001,
                    "number": 201,
                    "title": "Merged PR",
                    "state": "closed",
                    "html_url": "https://github.com/owner/repo/pull/201",
                    "user": {
                        "id": 2,
                        "login": "author",
                        "name": null,
                        "avatar_url": "https://example.com/author.png"
                    },
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-02T00:00:00Z",
                    "draft": false,
                    "requested_reviewers": \(reviewers),
                    "assignees": [],
                    "url": "https://api.github.com/repos/owner/repo/pulls/201",
                    "merged_at": "2024-01-02T00:00:00Z"
                }
            ]
        }
        """
    }
}
