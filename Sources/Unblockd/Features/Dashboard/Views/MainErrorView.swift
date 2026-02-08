import SwiftUI

struct MainErrorView<ActionView: View>: View {
    let error: DashboardError
    let actionView: ActionView

    init(error: DashboardError, @ViewBuilder action: () -> ActionView) {
        self.error = error
        self.actionView = action()
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(Color.ubStatusRed)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionView
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.ubStatusRed.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.ubStatusRed.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch error {
        case .authenticationFailed, .multipleAuthErrors: return "lock.slash.fill"
        case .networkRequestFailed: return "wifi.slash"
        case .rateLimitExceeded: return "hand.raised.fill"
        default: return "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch error {
        case .authenticationFailed: return "Authentication Failed"
        case .multipleAuthErrors(let providers):
             let names = providers.map { $0.displayName }.joined(separator: " & ")
             return "\(names) Auth Failed"
        case .networkRequestFailed: return "Connection Error"
        case .rateLimitExceeded: return "Rate Limit Exceeded"
        default: return "Something went wrong"
        }
    }

    private var message: String {
        error.localizedDescription
    }
}
