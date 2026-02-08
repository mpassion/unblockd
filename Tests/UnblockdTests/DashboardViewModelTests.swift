import XCTest
@testable import Unblockd

final class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!
    var mockClient: BitbucketClient!
    var repoService: RepositoryService!
    var session: URLSession!

    override func setUp() {
        super.setUp()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        mockClient = BitbucketClient(session: session)

        UserDefaults.standard.removeObject(forKey: AppConfig.Keys.monitoredRepos)
        repoService = RepositoryService()

        let dummyRepo = MonitoredRepository(id: "uuid-1", slug: "repo-1", workspace: "team", name: "Repo 1", fullName: "team/repo-1")
        repoService.monitoredRepositories = [dummyRepo]
    }

    override func tearDown() {
        viewModel = nil
        mockClient = nil
        repoService = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    @MainActor
    func testRefresh_Success() async {
        let userJSON = """
        { "uuid": "{user-uuid}", "display_name": "Test User", "account_id": "123", "nickname": "tester" }
        """

        let prJSON = """
        {
            "values": [
                {
                    "id": 1,
                    "title": "PR 1",
                    "state": "OPEN",
                    "updated_on": "2023-01-01T12:00:00Z",
                    "comment_count": 0,
                    "author": { "display_name": "Author", "uuid": "{author}", "links": {} },
                    "destination": { "repository": { "name": "Repo 1", "full_name": "team/repo-1", "uuid": "{repo-uuid}" } },
                    "reviewers": [],
                    "participants": [],
                    "links": { "html": { "href": "http://bitbucket.org" } }
                }
            ]
        }
        """

        let header200 = HTTPURLResponse(url: URL(string: "https://api.bitbucket.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)!

        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("/user") == true {
                return (header200, userJSON.data(using: .utf8)!)
            }
            if request.url?.path.contains("/pullrequests") == true {
                return (header200, prJSON.data(using: .utf8)!)
            }
            return (header200, Data())
        }

        viewModel = DashboardViewModel(repoService: repoService, lifecycle: .manual)
        await viewModel.refresh(force: true)

        XCTAssertNotNil(viewModel.lastUpdated)
    }

    @MainActor
    func testRefresh_AuthFailed() async {
        let header401 = HTTPURLResponse(url: URL(string: "https://api.bitbucket.org")!, statusCode: 401, httpVersion: nil, headerFields: nil)!

        MockURLProtocol.requestHandler = { request in
            return (header401, Data())
        }

        viewModel = DashboardViewModel(repoService: repoService, lifecycle: .manual)
        await viewModel.refresh(force: true)

        guard case .authenticationFailed(let provider)? = viewModel.lastError else {
            XCTFail("Expected authenticationFailed error, got \(String(describing: viewModel.lastError))")
            return
        }
        XCTAssertEqual(provider, .bitbucket)
    }
}
