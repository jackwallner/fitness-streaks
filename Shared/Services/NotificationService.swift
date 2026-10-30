import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "Notifications")

/// Local notifications for at-risk streaks. One reminder at a time, for the next occurrence,
/// rebuilt on every load.
@MainActor
enum NotificationService {
    static let dailyReminderID = "streaks.dailyReminder"
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

    /// Schedule a daily reminder. The body uses the most urgent incomplete streak so the nudge feels personal.
    /// Never prompts for permission — that only happens via a user-initiated toggle.
    static func scheduleDailyReminder(for streaks: [Streak]) async {
        let enabled = StreakSettings.shared.notificationsEnabled
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        guard enabled,
              StoreKitService.shared.isPro,
              await isAuthorized(),
              let plan = reminderPlan(
                  for: streaks,
                  now: .now,
                  hour: StreakSettings.shared.notificationHour,
                  minute: StreakSettings.shared.notificationMinute
              ) else { return }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.interruptionLevel = .active

        let trigger = UNCalendarNotificationTrigger(dateMatching: plan.fireComponents, repeats: plan.repeats)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            log.info("Scheduled daily streak reminder")
        } catch {
            log.error("Failed to schedule reminder: \(String(describing: error))")
        }
    }

    struct ReminderPlan: Equatable {
        let title: String
        let body: String
        let fireComponents: DateComponents
        let repeats: Bool
    }

    /// The next reminder, as a one-shot request rebuilt on every load. A repeating
    /// trigger would keep firing the same text and count on days the app never
    /// checked, met or not.
    ///
    /// Today's reminder names the most urgent unfinished streak. Once today's time
    /// has passed, or every goal is already met, it moves to tomorrow and names
    /// the longest streak, since every goal starts unfinished then.
    nonisolated static func reminderPlan(for streaks: [Streak], now: Date, hour: Int, minute: Int) -> ReminderPlan? {
        let calendar = DateHelpers.gregorian
        let today = DateHelpers.startOfDay(now)
        guard let todayFire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else { return nil }

        let fireDate: Date
        let reminder: Streak
        let body: String
        if todayFire > now, let urgent = bestReminderCandidate(from: streaks) {
            fireDate = todayFire
            reminder = urgent
            body = "You're at \(urgent.current) \(urgent.cadence.pluralLabel). Get it in \(deadline(for: urgent))."
        } else {
            let longest = streaks
                .filter { $0.current >= 2 }
                .max { $0.current < $1.current }
            guard let longest,
                  let tomorrowFire = calendar.date(byAdding: .day, value: 1, to: todayFire) else { return nil }
            fireDate = tomorrowFire
            reminder = longest
            body = "Get it in \(deadline(for: longest))."
        }

        return ReminderPlan(
            title: "Keep the \(reminder.thresholdLabel) streak alive",
            body: body,
            fireComponents: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
    }

    nonisolated private static func deadline(for streak: Streak) -> String {
        if let window = streak.window { return "by \(window.label)" }
        return streak.cadence == .weekly ? "this week" : "before midnight"
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
        content.title = "Streak ended"
        content.body = "Your \(broken.metric.displayName.lowercased()) streak ended at \(broken.brokenLength) \(broken.cadence.pluralLabel). Keep the same goal or pick a new one in the app."
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
