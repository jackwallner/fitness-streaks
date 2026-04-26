import SwiftUI

struct StreakHero: View {
    let streak: Streak

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                PixelFlame(size: 48, intensity: intensity, tint: Theme.retroMagenta)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HERO STREAK")
                        .font(RetroFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkDim)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak.current)")
                            .font(RetroFont.mono(44, weight: .bold))
                            .foregroundStyle(Theme.retroMagenta)
                            .retroGlow(Theme.retroMagenta)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(streak.cadence == .daily ? "DAYS" : "WKS")
                            .font(RetroFont.mono(11, weight: .bold))
                            .foregroundStyle(Theme.retroInk)
                    }
                    Text(heroProse)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            HStack {
                Text(chargeTitle)
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
                Text("best \(streak.best)")
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
        return streak.metric.prose(streak.threshold, cadence: streak.cadence)
    }

    private var chargeLabel: String {
        let v = streak.metric.format(value: streak.currentUnitValue)
        let t = streak.metric.format(value: streak.threshold)
        return "\(v)/\(t) \(streak.metric.unitLabel.uppercased())"
    }

    private var chargeTitle: String {
        if let w = streak.window {
            return "\(w.label.uppercased()) CHARGE"
        }
        return streak.cadence == .daily ? "TODAY'S CHARGE" : "THIS WEEK'S CHARGE"
    }

    private var intensity: CGFloat {
        let cap: Double = streak.cadence == .daily ? 30 : 8
        return CGFloat(min(1.0, 0.4 + Double(streak.current) / cap * 0.6))
    }
}
