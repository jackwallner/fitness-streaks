import SwiftUI

struct StreakBadgeRow: View {
    let streak: Streak

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(streak.metric.accent.opacity(0.18))
                Image(systemName: streak.metric.symbol)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(streak.metric.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(streak.metric.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(streak.current)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text(streak.cadence == .daily
                     ? (streak.current == 1 ? "day" : "days")
                     : (streak.current == 1 ? "week" : "weeks"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardSurface)
        )
    }

    private var subtitle: String {
        let label = streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence)
        if streak.currentUnitCompleted {
            return "\(label) · done today"
        }
        let unit = streak.cadence == .daily ? "today" : "this week"
        let pct = Int(min(1.0, streak.currentUnitProgress) * 100)
        return "\(label) · \(pct)% \(unit)"
    }
}
