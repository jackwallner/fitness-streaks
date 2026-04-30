import SwiftUI

/// Retained for any legacy callsites (onboarding, etc.) — thin wrapper around card.
struct StreakBadgeRow: View {
    let streak: Streak
    var body: some View { StreakBadgeCard(streak: streak) }
}

struct StreakBadgeCard: View {
    let streak: Streak

    private enum TypeScale {
        static let title: CGFloat = 9
        static let value: CGFloat = 22
        static let unit: CGFloat = 8.5
        static let goalLabel: CGFloat = 7
        static let goalValue: CGFloat = 8.5
        static let meta: CGFloat = 8.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent, radius: 6)
                    .frame(width: 18, height: 18)
                Text(titleText)
                    .font(RetroFont.mono(TypeScale.title, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroInkDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if streak.currentUnitCompleted {
                    Text("✓")
                        .font(RetroFont.mono(13, weight: .bold))
                        .foregroundStyle(Theme.retroLime)
                        .shadow(color: Theme.retroLime.opacity(0.8), radius: 4)
                }
            }

            HStack(alignment: .center, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currentValue)
                        .font(RetroFont.mono(TypeScale.value, weight: .bold))
                        .foregroundStyle(streak.metric.accent)
                        .retroGlow(streak.metric.accent, radius: 6)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                    Text(streak.unitLabel.uppercased())
                        .font(RetroFont.mono(TypeScale.unit, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .layoutPriority(1)

                Spacer(minLength: 2)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("GOAL")
                        .font(RetroFont.mono(TypeScale.goalLabel, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Text(goalValueLine.uppercased())
                        .font(RetroFont.mono(TypeScale.goalValue, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }

            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent,
                             segments: 10,
                             height: 8)

            HStack(spacing: 4) {
                Text(chargeLabel)
                    .font(RetroFont.mono(TypeScale.meta, weight: .bold))
                    .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent)
                Spacer(minLength: 0)
            }
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

    private var goalValueLine: String {
        let target = streak.format(currentUnitValue: streak.threshold)
        return "\(target) \(streak.unitLabel)"
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
