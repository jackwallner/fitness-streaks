import SwiftUI

/// Retained for any legacy callsites (onboarding, etc.) — thin wrapper around card.
struct StreakBadgeRow: View {
    let streak: Streak
    var body: some View { StreakBadgeCard(streak: streak) }
}

struct StreakBadgeCard: View {
    let streak: Streak

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent, radius: 6)
                    .frame(width: 18, height: 18)
                Text(titleText)
                    .font(RetroFont.mono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroInkDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if streak.currentUnitCompleted {
                    Text("✓")
                        .font(RetroFont.mono(14, weight: .bold))
                        .foregroundStyle(Theme.retroLime)
                        .shadow(color: Theme.retroLime.opacity(0.8), radius: 4)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currentValue)
                    .font(RetroFont.mono(24, weight: .bold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent, radius: 6)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(streak.unitLabel.uppercased())
                    .font(RetroFont.mono(9, weight: .bold))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent,
                             segments: 10,
                             height: 8)

            Text(chargeLabel)
                .font(RetroFont.mono(9, weight: .bold))
                .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: streak.currentUnitCompleted ? streak.metric.accent : Theme.retroInkFaint)
        .background(
            streak.currentUnitCompleted ?
            Theme.retroLime.opacity(0.08) : Color.clear
        )
    }

    private var titleText: String {
        if let w = streak.window {
            return "\(streak.displayName.uppercased()) · \(w.label.uppercased())"
        }
        return streak.displayName.uppercased()
    }

    private var chargeLabel: String {
        let t = streak.format(currentUnitValue: streak.threshold)
        let unit = streak.current == 1 ? streak.cadence.label : streak.cadence.pluralLabel
        if streak.currentUnitCompleted {
            return "\(streak.current) \(unit) · LOCKED"
        } else {
            let pct = Int(min(1, streak.currentUnitProgress) * 100)
            return "\(pct)% · \(streak.current) \(unit)"
        }
    }

    private var currentValue: String {
        streak.format(currentUnitValue: streak.currentUnitValue)
    }
}
