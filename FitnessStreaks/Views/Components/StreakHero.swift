import SwiftUI

struct StreakHero: View {
    let streak: Streak

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .retroGlow(streak.metric.accent)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PRIMARY STREAK")
                        .font(RetroFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkDim)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak.current)")
                            .font(RetroFont.mono(36, weight: .bold))
                            .foregroundStyle(Theme.retroMagenta)
                            .retroGlow(Theme.retroMagenta)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(streak.cadence == .daily ? "DAYS" : "WKS")
                            .font(RetroFont.mono(11, weight: .bold))
                            .foregroundStyle(Theme.retroInk)
                    }
                    Text(heroProse)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            HStack {
                Text(progressTitle)
                    .font(RetroFont.mono(9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
                Spacer()
                Text(chargeLabel)
                    .font(RetroFont.mono(9, weight: .bold))
                    .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
            }

            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)

            HStack(spacing: 4) {
                Text("best \(streak.best) in \(streak.lookbackDays)d")
                if let s = streak.startDate {
                    Text("· since \(DateHelpers.shortDate(s).lowercased())")
                }
            }
            .font(RetroFont.mono(10))
            .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta)
    }

    private var heroProse: String {
        if let w = streak.window {
            let t = streak.metric.format(value: streak.threshold)
            return "\(t)+ \(streak.metric.unitLabel) between \(w.label)"
        }
        return streak.prose
    }

    private var chargeLabel: String {
        let v = streak.format(currentUnitValue: streak.currentUnitValue)
        let t = streak.format(currentUnitValue: streak.threshold)
        return "\(v)/\(t) \(streak.unitLabel.uppercased())"
    }

    private var progressTitle: String {
        if let w = streak.window {
            return "\(w.label.uppercased()) PROGRESS"
        }
        return "TODAY'S PROGRESS"
    }

    private var intensity: CGFloat {
        let cap: Double = 30
        return CGFloat(min(1.0, 0.4 + Double(streak.current) / cap * 0.6))
    }
}
