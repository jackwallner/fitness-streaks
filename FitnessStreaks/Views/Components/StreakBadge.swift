import SwiftUI

/// Retained for any legacy callsites (onboarding, etc.) — thin wrapper around card.
struct StreakBadgeRow: View {
    let streak: Streak
    var body: some View { StreakBadgeCard(streak: streak) }
}

struct StreakBadgeCard: View {
    let streak: Streak

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: streak.metric.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(streak.metric.accent)
                        .shadow(color: streak.metric.accent.opacity(0.6), radius: 4)
                    Text(titleText)
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak.current)")
                        .font(RetroFont.pixel(26))
                        .foregroundStyle(streak.metric.accent)
                        .retroGlow(streak.metric.accent, radius: 10)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(streak.cadence == .daily ? "DAYS" : "WKS")
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroInkDim)
                }

                Text(subtitle)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineLimit(1)

                PixelBarThin(progress: streak.currentUnitProgress, accent: streak.metric.accent)
                    .padding(.top, 2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: streak.currentUnitCompleted ? streak.metric.accent : Theme.retroInkFaint)

            if streak.currentUnitCompleted {
                Text("✓")
                    .font(RetroFont.pixel(8))
                    .foregroundStyle(Theme.retroBg)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(streak.metric.accent)
            }
        }
    }

    private var subtitle: String {
        let label = streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence)
        return "\(label) · best \(streak.best)"
    }

    private var titleText: String {
        if let w = streak.window {
            return "\(streak.metric.displayName.uppercased()) · \(w.label.uppercased())"
        }
        return streak.metric.displayName.uppercased()
    }
}
