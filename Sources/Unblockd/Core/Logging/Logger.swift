import Foundation
import os

/// A unified logging wrapper using Apple's OSLog.
/// Usage:
///     Log.info("Application started")
///     Log.error("Failed to fetch data", error: error)
///     Log.network("Fetching PRs from Bitbucket")
enum Log {
    // Define subsystems/categories to filter logs in Console.app
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.unblockd"

    // Dedicated loggers for different parts of the app
    static let general = Logger(subsystem: subsystem, category: "General")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let data = Logger(subsystem: subsystem, category: "Data")

    // MARK: - Public API

    /// Log informative events (e.g., "User logged in", "Refresh started")
    static func info(_ message: String, category: Logger = general) {
        category.info("\(message, privacy: .public)")
    }

    /// Log errors and failures (e.g., "API 500", "Parsing failed")
    static func error(_ message: String, error: Error? = nil, category: Logger = general) {
        if let error = error {
            category.error("\(message, privacy: .public) | Error: \(error.localizedDescription, privacy: .public)")
        } else {
            category.error("\(message, privacy: .public)")
        }
    }

    /// Log debug details only useful for development (e.g., "Payload received: ...")
    static func debug(_ message: String, category: Logger = general) {
        // OSLog handles debug stripping natively, but explicit check adds clarity
        #if DEBUG
        category.debug("\(message, privacy: .public)")
        #endif
    }

    /// Log faulty logic that isn't a crash but shouldn't happen
    static func warning(_ message: String, category: Logger = general) {
        category.warning("⚠️ \(message, privacy: .public)")
    }
}
