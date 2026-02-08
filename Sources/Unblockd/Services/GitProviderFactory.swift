import Foundation

enum GitProviderFactory {
    static func makeProvider(
        for type: ProviderType,
        username: String = "",
        token: String = "",
        session: URLSession = .shared
    ) -> any GitProvider {
        switch type {
        case .bitbucket:
            let client = BitbucketClient(session: session)
            client.setCredentials(username: username, token: token)
            return client
        case .github:
            let client = GitHubClient(session: session)
            client.setCredentials(username: "", token: token)
            return client
        case .gitlab:
            let client = GitLabClient(session: session)
            client.setCredentials(username: "", token: token)
            return client
        }
    }
}
