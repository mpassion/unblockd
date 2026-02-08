import XCTest
@testable import Unblockd

final class BitbucketClientTests: XCTestCase {
    var client: BitbucketClient!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        client = BitbucketClient(session: session)
    }

    override func tearDown() {
        client = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchRepositories_Success() async throws {
        let jsonString = """
        {
            "values": [
                {
                    "uuid": "{123}",
                    "name": "Repo A",
                    "full_name": "team/repo-a",
                    "is_private": true
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let repos = try await client.fetchRepositories()
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.name, "Repo A")
    }

    func testFetchRepositories_Unauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.fetchRepositories()
            XCTFail("Should have thrown error")
        } catch let error as GitProviderError {
            guard case .unauthorized = error else {
                XCTFail("Wrong error type: \(error)")
                return
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testFetchRepositories_RateLimit() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await client.fetchRepositories()
            XCTFail("Should have thrown error")
        } catch let error as GitProviderError {
            guard case .rateLimitExceeded = error else {
                XCTFail("Expected rateLimitExceeded, got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected rateLimitExceeded, got: \(error)")
        }
    }

    func testFetchRepositories_PaginationErrorIsPropagated() async {
        let firstPageJSON = """
        {
            "values": [],
            "next": "https://api.bitbucket.org/2.0/repositories?page=2"
        }
        """
        let header200 = HTTPURLResponse(url: URL(string: "https://api.bitbucket.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let header401 = HTTPURLResponse(url: URL(string: "https://api.bitbucket.org/2.0/repositories?page=2")!, statusCode: 401, httpVersion: nil, headerFields: nil)!

        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("page=2") == true {
                return (header401, Data())
            }
            return (header200, firstPageJSON.data(using: .utf8)!)
        }

        do {
            _ = try await client.fetchRepositories()
            XCTFail("Should throw when next page fails")
        } catch let error as GitProviderError {
            guard case .unauthorized = error else {
                XCTFail("Expected unauthorized, got: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
