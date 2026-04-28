import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "Notifications")

/// Local notifications for at-risk streaks. Fires once daily if the most urgent tracked streak
/// hasn't been completed yet for today.
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
              await isAuthorized(),
              let reminder = bestReminderCandidate(from: streaks) else { return }

        let heroLabel = reminder.metric.thresholdLabel(reminder.threshold, cadence: reminder.cadence)
        let unit = reminder.cadence.pluralLabel
        let deadline: String
        if let window = reminder.window {
            deadline = "by \(window.label)"
        } else if reminder.cadence == .weekly {
            deadline = "this week"
        } else {
            deadline = "before midnight"
        }

        let content = UNMutableNotificationContent()
        content.title = "Keep the \(heroLabel) streak alive"
        content.body = "You're at \(reminder.current) \(unit). Get it in \(deadline)."
        content.sound = .default
        content.interruptionLevel = .active

        var comps = DateComponents()
        comps.hour = StreakSettings.shared.notificationHour
        comps.minute = StreakSettings.shared.notificationMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            log.info("Scheduled daily streak reminder")
        } catch {
            log.error("Failed to schedule reminder: \(String(describing: error))")
        }
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
        guard await isAuthorized() else { return }

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
