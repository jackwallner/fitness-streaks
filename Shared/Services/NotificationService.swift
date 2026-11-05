import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "Notifications")

/// Local notifications for at-risk streaks. A queue of one-shot daily reminders,
/// rebuilt on every load.
@MainActor
enum NotificationService {
    nonisolated static let dailyReminderID = "streaks.dailyReminder"
    static let brokenPrefix = "streaks.broken."

    enum AuthorizationOutcome {
        case granted
        case denied            // user denied this prompt
        case previouslyDenied  // permission already denied — UI should deep-link to Settings
    }

    /// Explicit opt-in. Only call this from a user-initiated toggle so the system prompt
    /// never appears unsolicited (App Store guideline 5.1.1).
    static func requestAuthorization() async -> AuthorizationOutcome {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted ? .granted : .denied
        case .denied:
            return .previouslyDenied
        default:
            return .granted
        }
    }

    /// Whether notifications are already authorized — does NOT trigger the system prompt.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }
        #if os(iOS)
        if settings.authorizationStatus == .ephemeral { return true }
        #endif
        return false
    }

    /// How many days of reminders are queued ahead. Each successful load replaces
    /// the whole queue, so a user who stops opening the app (and stops getting
    /// background refresh) still gets a nudge every day for this long.
    nonisolated static let reminderHorizonDays = 30

    /// Queue the daily reminder: today's with the live count when it is still ahead,
    /// then one per day for `reminderHorizonDays` days with text that holds no count.
    /// Never prompts for permission. That only happens via a user-initiated toggle.
    static func scheduleDailyReminder(for streaks: [Streak]) async {
        let center = UNUserNotificationCenter.current()
        cancelAll()

        guard StreakSettings.shared.notificationsEnabled,
              StoreKitService.shared.isPro,
              await isAuthorized() else { return }

        let plans = reminderPlans(
            for: streaks,
            now: .now,
            hour: StreakSettings.shared.notificationHour,
            minute: StreakSettings.shared.notificationMinute
        )
        for (index, plan) in plans.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.interruptionLevel = .active

            let trigger = UNCalendarNotificationTrigger(dateMatching: plan.fireComponents, repeats: false)
            let request = UNNotificationRequest(identifier: reminderID(index), content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                log.error("Failed to schedule reminder: \(String(describing: error))")
            }
        }
        log.info("Scheduled \(plans.count) streak reminders")
    }

    nonisolated static func reminderID(_ index: Int) -> String {
        "\(dailyReminderID).\(index)"
    }

    /// Every reminder ID this or an earlier build may have queued, including the
    /// single repeating request from before the queue.
    nonisolated static var allReminderIDs: [String] {
        [dailyReminderID] + (0...reminderHorizonDays).map(reminderID)
    }

    struct ReminderPlan: Equatable {
        let title: String
        let body: String
        let fireComponents: DateComponents
    }

    /// The queued reminders, soonest first, as one-shot requests. A repeating
    /// trigger would keep firing the same count on days the app never checked.
    ///
    /// Today's reminder names the most urgent unfinished streak and its count.
    /// Once today's time has passed, or every goal is already met, today is
    /// skipped. Every later day names the longest streak's goal with no count,
    /// so it still reads true however many days go by without a load.
    /// Empty when no streak has reached 2, which clears the queue.
    nonisolated static func reminderPlans(
        for streaks: [Streak],
        now: Date,
        hour: Int,
        minute: Int,
        days: Int = reminderHorizonDays
    ) -> [ReminderPlan] {
        let calendar = DateHelpers.gregorian
        let today = DateHelpers.startOfDay(now)
        guard let todayFire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today),
              let longest = streaks.filter({ $0.current >= 2 }).max(by: { $0.current < $1.current })
        else { return [] }

        func components(_ date: Date) -> DateComponents {
            calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        }

        var plans: [ReminderPlan] = []
        if todayFire > now, let urgent = bestReminderCandidate(from: streaks) {
            plans.append(ReminderPlan(
                title: String(localized: "Keep the \(urgent.thresholdLabel) streak alive"),
                body: urgentBody(for: urgent),
                fireComponents: components(todayFire)
            ))
        }
        for offset in 1...max(days, 1) {
            guard let fire = calendar.date(byAdding: .day, value: offset, to: todayFire) else { continue }
            plans.append(ReminderPlan(
                title: String(localized: "Time for \(longest.thresholdLabel)"),
                body: laterBody(for: longest),
                fireComponents: components(fire)
            ))
        }
        return plans
    }

    nonisolated private static func urgentBody(for streak: Streak) -> String {
        let n = streak.current
        switch (streak.window?.label, streak.cadence) {
        case let (window?, .daily): return String(localized: "You're at \(n) days. Get it in by \(window).")
        case let (window?, .weekly): return String(localized: "You're at \(n) weeks. Get it in by \(window).")
        case (nil, .weekly): return String(localized: "You're at \(n) weeks. Get it in this week.")
        case (nil, .daily): return String(localized: "You're at \(n) days. Get it in before midnight.")
        }
    }

    nonisolated private static func laterBody(for streak: Streak) -> String {
        if let window = streak.window?.label {
            return String(localized: "Get it in by \(window) to keep your streak going.")
        }
        return streak.cadence == .weekly
            ? String(localized: "Get it in this week to keep your streak going.")
            : String(localized: "Get it in before midnight to keep your streak going.")
    }

    nonisolated static func bestReminderCandidate(from streaks: [Streak]) -> Streak? {
        streaks
            .filter { !$0.currentUnitCompleted && $0.current >= 2 }
            .sorted {
                if $0.current != $1.current { return $0.current > $1.current }
                return $0.currentUnitProgress < $1.currentUnitProgress
            }
            .first
    }

    static func notifyStreakBroken(_ broken: BrokenStreak) async {
        guard StreakSettings.shared.notificationsEnabled, await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Streak ended")
        let metricName = broken.metric.lowerName
        let length = broken.brokenLength
        switch broken.cadence {
        case .daily:
            content.body = String(localized: "Your \(metricName) streak ended at \(length) days. Keep the same goal or pick a new one in the app.")
        case .weekly:
            content.body = String(localized: "Your \(metricName) streak ended at \(length) weeks. Keep the same goal or pick a new one in the app.")
        }
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: "\(brokenPrefix)\(broken.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            log.error("Failed to schedule broken streak notification: \(String(describing: error))")
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allReminderIDs)
    }
}
