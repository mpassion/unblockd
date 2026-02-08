import Foundation
import SwiftUI

@MainActor
class RateLimitTracker: ObservableObject {
    static let shared = RateLimitTracker()

    @Published var usage: [ProviderType: Int] = [.bitbucket: 0, .github: 0, .gitlab: 0]
    @Published var isLimited: Bool = false
    @Published var hourStartTime: Date = Date()
    @Published var resetTime: Date?

    private let defaults = UserDefaults.standard
    private let kUsage = "rate_limit_usage"
    private let kStartTime = "rate_limit_start_time"

    private init() {
        loadState()
    }

    func limit(for provider: ProviderType) -> Int {
        if provider == .github {
            let val = defaults.integer(forKey: AppConfig.Keys.rateLimitGitHub)
            return val > 0 ? val : AppConfig.Defaults.rateLimitGitHub
        } else if provider == .gitlab {
            let val = defaults.integer(forKey: AppConfig.Keys.rateLimitGitLab)
            return val > 0 ? val : AppConfig.Defaults.rateLimitGitLab
        } else {
            let val = defaults.integer(forKey: AppConfig.Keys.rateLimitBitbucket)
            return val > 0 ? val : AppConfig.Defaults.rateLimitBitbucket
        }
    }

    func warningLimit(for provider: ProviderType) -> Int {
        let max = limit(for: provider)
        return Int(Double(max) * 0.9)
    }

    func recordCall(provider: ProviderType = .bitbucket) {
        checkReset()
        usage[provider, default: 0] += 1
        saveState()
    }

    func reportLimitReached() {
        isLimited = true
        let nextHour = hourStartTime.addingTimeInterval(3600)
        resetTime = nextHour > Date() ? nextHour : Date().addingTimeInterval(3600)
        saveState()
    }

    func checkReset() {
        let now = Date()
        if now.timeIntervalSince(hourStartTime) > 3600 {
            usage = [.bitbucket: 0, .github: 0, .gitlab: 0]
            hourStartTime = now
            isLimited = false
            resetTime = nil
            saveState()
        }
    }

    func reset() {
        usage = [.bitbucket: 0, .github: 0, .gitlab: 0]
        hourStartTime = Date()
        isLimited = false
        resetTime = nil
        saveState()
    }

    private func saveState() {
        // Simple serialization for dictionary keys using rawValue
        let rawUsage = Dictionary(uniqueKeysWithValues: usage.map { ($0.key.rawValue, $0.value) })
        defaults.set(rawUsage, forKey: kUsage)
        defaults.set(hourStartTime, forKey: kStartTime)
    }

    private func loadState() {
        if let rawUsage = defaults.dictionary(forKey: kUsage) as? [String: Int] {
            var newUsage: [ProviderType: Int] = [:]
            for (key, val) in rawUsage {
                if let type = ProviderType(rawValue: key) {
                    newUsage[type] = val
                }
            }
            usage = newUsage
        }

        if let start = defaults.object(forKey: kStartTime) as? Date {
            hourStartTime = start
        } else {
            hourStartTime = Date()
        }

        checkReset()
    }

    var warningLevel: WarningLevel {
        // Return worst case
        let bbLevel = level(for: .bitbucket)
        let ghLevel = level(for: .github)
        let glLevel = level(for: .gitlab)

        let maxLevel = [bbLevel, ghLevel, glLevel].max { $0.priority < $1.priority }
        return maxLevel ?? .none
    }

    private func level(for provider: ProviderType) -> WarningLevel {
        let count = usage[provider, default: 0]
        let max = limit(for: provider)
        let percentage = Double(count) / Double(max)

        switch percentage {
        case 0..<0.5: return .none
        case 0.5..<0.7: return .low
        case 0.7..<0.9: return .medium
        default: return .high
        }
    }

    enum WarningLevel: Int {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3

        var priority: Int { rawValue }

        var color: Color {
            switch self {
            case .none: return .clear
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    // Header parsing
    nonisolated func track(response: HTTPURLResponse, provider: ProviderType) {
        Task { @MainActor in
            let isRateLimitResponse = response.statusCode == 429 || (provider == .github && response.statusCode == 403)
            if isRateLimitResponse {
                reportLimitReached()
            } else {
                recordCall(provider: provider)
            }
        }
    }

    // UI Helpers
    var callsThisHour: Int {
        usage.values.reduce(0, +)
    }

    var totalLimit: Int {
        limit(for: .bitbucket) + limit(for: .github) + limit(for: .gitlab)
    }
}
