import SwiftUI

struct StreakHero: View {
    let streak: Streak

    private var accent: Color {
        streak.currentUnitCompleted ? Theme.retroLime : Theme.retroMagenta
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(RetroFont.mono(17, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.metric.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(goalContext.uppercased())
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(currentValue)
                    .font(RetroFont.mono(44, weight: .bold))
                    .foregroundStyle(accent)
                    .retroGlow(accent)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)

                Text(goalLine)
                    .font(RetroFont.mono(12, weight: .medium))
                    .foregroundStyle(Theme.retroInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(streakLine)
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
                }

                PixelProgressBar(progress: streak.currentUnitProgress,
                                 accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: accent)
    }

    private var titleText: String {
        if let w = streak.window {
            return "\(streak.displayName.uppercased()) · \(w.label.uppercased())"
        }
        return streak.displayName.uppercased()
    }

    private var currentValue: String {
        streak.format(currentUnitValue: streak.currentUnitValue)
    }

    private var goalLine: String {
        "of \(streak.format(currentUnitValue: streak.threshold)) \(streak.unitLabel) goal"
    }

    private var goalContext: String {
        if let w = streak.window {
            return "\(w.label) goal"
        }
        return streak.cadence == .daily ? "today's goal" : "this week's goal"
    }

    private var streakLine: String {
        let unit = streak.current == 1 ? streak.cadence.label : streak.cadence.pluralLabel
        return "\(streak.current) \(unit) streak"
    }

    private var statusText: String {
        if streak.currentUnitCompleted { return "LOCKED" }
        return "\(Int(min(1, streak.currentUnitProgress) * 100))% COMPLETE"
    }
}
