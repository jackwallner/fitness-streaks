import Foundation

/// Locale-aware number strings for copy. `String(format: "%.1f")` always prints a
/// period, so "7.5 hr" read wrong in every comma-decimal language.
enum LocalizedNumber {
    /// Fixed fraction digits, no grouping: "7.5" / "7,5".
    static func fixed(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never))
    }

    /// One decimal under 10, whole above: "3.5" / "12".
    static func oneDecimalUnderTen(_ value: Double) -> String {
        fixed(value, digits: value < 10 ? 1 : 0)
    }

    /// Whole number with the locale's grouping: "10,000" / "10.000".
    static func grouped(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
