import SwiftUI

struct StreakHero: View {
    let streak: Streak

    private enum TypeScale {
        static let title: CGFloat = 16
        static let context: CGFloat = 9.5
        static let value: CGFloat = 42
        static let unit: CGFloat = 10
        static let goalLabel: CGFloat = 8
        static let goalValue: CGFloat = 10
        static let meta: CGFloat = 10
    }

    private var valueColor: Color {
        streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent
    }

    private var panelColor: Color {
        streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(RetroFont.mono(TypeScale.title, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.metric.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(goalContext.uppercased())
                        .font(RetroFont.mono(TypeScale.context, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent)
                    .frame(width: 34, height: 34)
            }

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currentValue)
                        .font(RetroFont.mono(TypeScale.value, weight: .bold))
                        .foregroundStyle(valueColor)
                        .retroGlow(valueColor)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                    Text(streak.unitLabel.uppercased())
                        .font(RetroFont.mono(TypeScale.unit, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("GOAL")
                        .font(RetroFont.mono(TypeScale.goalLabel, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Text(goalLine.uppercased())
                        .font(RetroFont.mono(TypeScale.goalValue, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            Spacer(minLength: 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(streakLine)
                        .font(RetroFont.mono(TypeScale.meta, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(RetroFont.mono(TypeScale.meta, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
                }

                PixelProgressBar(progress: streak.currentUnitProgress,
                                 accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .leading)
        .pixelPanel(color: panelColor)
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
        let target = streak.format(currentUnitValue: streak.threshold)
        return "\(target) \(streak.unitLabel)"
    }

    private var goalContext: String {
        if let w = streak.window {
            return "\(w.label) target"
        }
        return streak.cadence == .daily ? "today" : "this week"
    }

    private var streakLine: String {
        let unit = streak.current == 1 ? streak.cadence.label : streak.cadence.pluralLabel
        return "\(streak.current) \(unit) streak"
    }

    private var statusText: String {
        streak.currentUnitCompleted ? "LOCKED" : "\(Int(min(1, streak.currentUnitProgress) * 100))%"
    }
}
