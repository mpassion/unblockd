import XCTest
@testable import Unblockd

final class GitHubClientTests: XCTestCase {
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

    func testFetchRepositories_ForbiddenMapsToRateLimitExceeded() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.fetchRepositories(query: nil)
            XCTFail("Should throw for 403")
        } catch let error as GitProviderError {
            guard case .rateLimitExceeded = error else {
                XCTFail("Expected rateLimitExceeded, got: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchPRs_InvalidRepositoryFullNameThrowsInvalidURL() async {
        let userJSON = """
        {
            "id": 1,
            "login": "octocat",
            "name": "The Octocat",
            "avatar_url": "https://example.com/avatar.png"
        }
        """
        var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, userJSON.data(using: .utf8)!)
        }

        let invalidRepo = GitRepository(
            id: "1",
            name: "invalid",
            fullName: "invalid-full-name",
            url: nil,
            provider: .github
        )

        do {
            _ = try await client.fetchPRs(for: invalidRepo)
            XCTFail("Should throw invalidURL for malformed fullName")
        } catch let error as GitProviderError {
            guard case .invalidURL = error else {
                XCTFail("Expected invalidURL, got: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(requestCount, 1, "Only /user should be requested before fullName validation fails")
    }
}
