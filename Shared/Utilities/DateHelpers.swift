import Foundation

enum DateHelpers {
    static let gregorian: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday; matches ISO week and how weekly thresholds read most naturally
        return cal
    }()

    static func startOfDay(_ date: Date = .now) -> Date {
        gregorian.startOfDay(for: date)
    }

    static func daysAgo(_ days: Int, from date: Date = .now) -> Date {
        gregorian.date(byAdding: .day, value: -days, to: startOfDay(date)) ?? startOfDay(date)
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Monday 00:00 for the week containing `date`.
    static func startOfWeek(_ date: Date = .now) -> Date {
        let start = startOfDay(date)
        let comps = gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
        return gregorian.date(from: comps) ?? start
    }

    static func addWeeks(_ weeks: Int, to date: Date) -> Date {
        gregorian.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }

    static func dayKey(_ date: Date) -> String {
        let cal = gregorian
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static func shortDate(_ date: Date) -> String { shortFormatter.string(from: date) }
    static func dayOfWeek(_ date: Date) -> String { dayOfWeekFormatter.string(from: date) }
}
