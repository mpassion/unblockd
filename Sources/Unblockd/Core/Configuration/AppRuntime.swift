import Foundation

enum AppRuntime {
    static let demoModeArgument = "--demo-data"
    static let demoModeEnvironmentKey = "UNBLOCKD_DEMO_MODE"

    static var isDemoMode: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(demoModeArgument) {
            return true
        }

        let envValue = ProcessInfo.processInfo.environment[demoModeEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return envValue == "1" || envValue == "true" || envValue == "yes" || envValue == "on"
    }
}
