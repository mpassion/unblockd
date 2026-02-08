import XCTest
@testable import Unblockd

final class GitHubClientConcurrencyTests: XCTestCase {
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

    func testFetchPRs_ReviewFetchConcurrencyIsBounded() async throws {
        let lock = NSLock()
        var activeReviewRequests = 0
        var maxConcurrentReviewRequests = 0

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

            switch (url.path, url.query ?? "") {
            case ("/user", _):
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls", let query) where query.contains("state=open"):
                return (response, self.openPRsJSON(count: 12).data(using: .utf8)!)
            case ("/search/issues", _):
                return (response, "{\"total_count\":0,\"items\":[]}".data(using: .utf8)!)
            case (let path, _) where path.hasPrefix("/repos/owner/repo/pulls/") && path.hasSuffix("/reviews"):
                lock.lock()
                activeReviewRequests += 1
                if activeReviewRequests > maxConcurrentReviewRequests {
                    maxConcurrentReviewRequests = activeReviewRequests
                }
                lock.unlock()

                Thread.sleep(forTimeInterval: 0.03)

                lock.lock()
                activeReviewRequests -= 1
                lock.unlock()

                return (response, "[]".data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        _ = try await client.fetchPRs(for: repo)

        XCTAssertLessThanOrEqual(maxConcurrentReviewRequests, AppConfig.Limits.githubReviewFetchConcurrency)
    }

    func testZFetchPRs_RateLimitStopsSchedulingAdditionalReviewRequests() async throws {
        let lock = NSLock()
        var totalReviewRequests = 0

        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)

            switch (url.path, url.query ?? "") {
            case ("/user", _):
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, self.userJSON.data(using: .utf8)!)
            case ("/repos/owner/repo/pulls", let query) where query.contains("state=open"):
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, self.openPRsJSON(count: 20).data(using: .utf8)!)
            case ("/search/issues", _):
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "{\"total_count\":0,\"items\":[]}".data(using: .utf8)!)
            case (let path, _) where path.hasPrefix("/repos/owner/repo/pulls/") && path.hasSuffix("/reviews"):
                lock.lock()
                totalReviewRequests += 1
                lock.unlock()

                if path.contains("/pulls/1/reviews") {
                    let rateLimited = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
                    return (rateLimited, Data())
                }

                Thread.sleep(forTimeInterval: 0.05)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, "[]".data(using: .utf8)!)
            default:
                let notFound = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (notFound, Data())
            }
        }

        do {
            _ = try await client.fetchPRs(for: repo)
            XCTFail("Expected rateLimitExceeded")
        } catch let error as GitProviderError {
            guard case .rateLimitExceeded = error else {
                return XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        }

        XCTAssertLessThanOrEqual(totalReviewRequests, AppConfig.Limits.githubReviewFetchConcurrency)
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

    private func openPRsJSON(count: Int) -> String {
        let items = (1...count).map { n in
            """
            {
                "id": \(10_000 + n),
                "number": \(n),
                "title": "PR #\(n)",
                "state": "open",
                "html_url": "https://github.com/owner/repo/pull/\(n)",
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
                "url": "https://api.github.com/repos/owner/repo/pulls/\(n)",
                "merged_at": null
            }
            """
        }.joined(separator: ",")

        return "[\(items)]"
    }
}
