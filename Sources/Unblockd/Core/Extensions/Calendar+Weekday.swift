import Foundation

extension Calendar {
    /// Returns the short weekday name (e.g., "M", "T") for a given weekday index (1...7).
    /// Safe: Returns empty string if index is invalid.
    func shortWeekdayName(for weekdayIndex: Int) -> String {
        // weekdayIndex is 1-based (1=Sunday), symbols array is 0-based.
        let shortNames = ["S", "M", "T", "W", "T", "F", "S"]
        guard weekdayIndex >= 1 && weekdayIndex <= 7 else { return "" }
        return shortNames[weekdayIndex - 1]
    }

    /// Returns the full weekday name (e.g., "Monday") for a given weekday index (1...7).
    /// Safe: Returns empty string if index is invalid.
    func fullWeekdayName(for weekdayIndex: Int) -> String {
        let fullNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard weekdayIndex >= 1 && weekdayIndex <= 7 else { return "" }
        return fullNames[weekdayIndex - 1]
    }
}
