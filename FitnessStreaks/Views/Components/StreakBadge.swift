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
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroLime)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streak.current)")
                    .font(RetroFont.mono(26, weight: .bold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent, radius: 6)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(streak.cadence == .daily ? "DAYS" : "WKS")
                    .font(RetroFont.mono(10, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
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
    }

    private var titleText: String {
        if let w = streak.window {
            return "\(streak.displayName.uppercased()) · \(w.label.uppercased())"
        }
        return streak.displayName.uppercased()
    }

    private var chargeLabel: String {
        let v = streak.format(currentUnitValue: streak.currentUnitValue)
        let t = streak.format(currentUnitValue: streak.threshold)
        return "\(v)/\(t) \(streak.unitLabel.uppercased())"
    }

    private var progressTitle: String {
        if let w = streak.window {
            return "\(w.label.uppercased())"
        }
        return streak.cadence == .daily ? "TODAY" : "THIS WK"
    }
}
