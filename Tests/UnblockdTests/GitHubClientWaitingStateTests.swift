import XCTest
@testable import Unblockd

final class GitHubClientWaitingStateTests: XCTestCase {
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

    func testFetchPRs_ChangesRequestedByMeIsWaiting() async throws {
        let userJSON = """
        {
            "id": 1,
            "login": "me",
            "name": "Me",
            "avatar_url": "https://example.com/me.png"
        }
        """

        let openPRsJSON = """
        [
            {
                "id": 1001,
                "number": 101,
                "title": "Needs updates",
                "state": "open",
                "html_url": "https://github.com/owner/repo/pull/101",
                "user": {
                    "id": 2,
                    "login": "author",
                    "name": null,
                    "avatar_url": "https://example.com/author.png"
                },
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-02T00:00:00Z",
                "draft": false,
                "requested_reviewers": [
                    {
                        "id": 1,
                        "login": "me",
                        "name": "Me",
                        "avatar_url": "https://example.com/me.png"
                    }
                ],
                "assignees": [],
                "url": "https://api.github.com/repos/owner/repo/pulls/101",
                "merged_at": null
            }
        ]
        """

        let mergedSearchJSON = """
        {
            "total_count": 0,
            "items": []
        }
        """

        let reviewsJSON = """
        [
            {
                "id": 9001,
                "user": {
                    "id": 1,
                    "login": "me",
                    "name": "Me",
                    "avatar_url": "https://example.com/me.png"
                },
                "state": "CHANGES_REQUESTED",
                "submitted_at": "2024-01-03T00:00:00Z"
            }
        ]
        """

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch (url.path, url.query ?? "") {
            case ("/user", _):
                return (response, userJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls", let query) where query.contains("state=open"):
                return (response, openPRsJSON.data(using: .utf8)!)
            case ("/search/issues", _):
                return (response, mergedSearchJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls/101/reviews", _):
                return (response, reviewsJSON.data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        let repo = GitRepository(
            id: "repo-1",
            name: "repo",
            fullName: "owner/repo",
            url: URL(string: "https://github.com/owner/repo"),
            provider: .github
        )

        let items = try await client.fetchPRs(for: repo)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.state, .waiting)
        XCTAssertEqual(items.first?.hasChangesRequested, true)
    }
}
