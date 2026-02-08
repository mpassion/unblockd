import SwiftUI

struct CompactErrorBanner<ActionView: View>: View {
    let error: DashboardError
    let actionView: ActionView

    init(error: DashboardError, @ViewBuilder action: () -> ActionView) {
        self.error = error
        self.actionView = action()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(providerName)
                    .font(.system(size: 11, weight: .semibold))
                Text(shortMessage)
                    .font(.system(size: 10))
                    .opacity(0.8)
            }

            Spacer()

            actionView
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ubStatusRed)
        .cornerRadius(8)
    }

    private var iconName: String {
        switch error {
        case .authenticationFailed, .multipleAuthErrors: return "lock.slash.fill"
        case .networkRequestFailed: return "wifi.slash"
        case .rateLimitExceeded: return "hand.raised.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var providerName: String {
        switch error {
        case .authenticationFailed(let p):
            return "\(p?.rawValue.capitalized ?? "Provider") Auth Failed"
        case .multipleAuthErrors(let providers):
            let names = providers.map { $0.displayName }.joined(separator: " & ")
            return "\(names) Auth Failed"
        case .networkRequestFailed(_, let p):
            return "\(p?.rawValue.capitalized ?? "Provider") Connection Error"
        case .rateLimitExceeded(_, let p):
            return "\(p?.rawValue.capitalized ?? "Provider") Rate Limited"
        default:
            return "Error"
        }
    }

    private var shortMessage: String {
        switch error {
        case .authenticationFailed, .multipleAuthErrors: return "Check credentials"
        case .networkRequestFailed: return "Check connection"
        case .rateLimitExceeded: return "Try again later"
        default: return "Something went wrong"
        }
    }
}
