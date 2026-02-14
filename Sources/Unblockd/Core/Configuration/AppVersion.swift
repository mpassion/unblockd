import Foundation

enum AppVersion {
    // SwiftPM development bundles may expose default bundle version values (1.0 / 1).
    // Keep fallback values in sync with release versioning.
    static let fallbackShortVersion = "0.9.3"
    static let fallbackBuildNumber = "4"

    static var shortVersion: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return fallbackShortVersion
        }
        return version == "1.0" ? fallbackShortVersion : version
    }

    static var buildNumber: String {
        if usesSwiftPMDefaultBundleVersion {
            return fallbackBuildNumber
        }
        return (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? fallbackBuildNumber
    }

    static var displayText: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    private static var usesSwiftPMDefaultBundleVersion: Bool {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return true
        }
        return version == "1.0"
    }
}
