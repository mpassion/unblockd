import Foundation

enum DashboardError: LocalizedError, Equatable {
    case networkRequestFailed(String, provider: ProviderType?)
    case authenticationFailed(provider: ProviderType?)
    case rateLimitExceeded(reset: Date?, provider: ProviderType?)
    case multipleAuthErrors([ProviderType])
    case unknown(String, provider: ProviderType?)

    var errorDescription: String? {
        switch self {
        case .networkRequestFailed(let message, let provider):
            return "\(provider?.displayName ?? "Network") Error: \(message)"
        case .authenticationFailed(let provider):
            return "\(provider?.displayName ?? "Authentication") Failed. Please check your credentials."
        case .rateLimitExceeded(let reset, let provider):
            let prefix = provider.map { "\($0.displayName) Rate Limit Exceeded" } ?? "Rate Limit Exceeded"
            if let date = reset {
                return "\(prefix). Resets at \(date.formatted(date: .omitted, time: .shortened))."
            }
            return "\(prefix)."
        case .multipleAuthErrors(let providers):
            let names = providers.map { $0.displayName }.joined(separator: " & ")
            return "\(names) Auth Failed. Check credentials."
        case .unknown(let message, _):
            return message
        }
    }
}
