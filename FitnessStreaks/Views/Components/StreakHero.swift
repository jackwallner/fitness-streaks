import SwiftUI

struct StreakHero: View {
    let streak: Streak

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HERO STREAK")
                .font(RetroFont.pixel(9))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)

            HStack(spacing: 14) {
                PixelFlame(size: 56, intensity: intensity, tint: Theme.retroMagenta)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(streak.current)")
                            .font(RetroFont.pixel(56))
                            .tracking(2)
                            .foregroundStyle(Theme.retroMagenta)
                            .retroGlow(Theme.retroMagenta)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(streak.cadence == .daily ? "DAYS" : "WKS")
                            .font(RetroFont.pixel(12))
                            .foregroundStyle(Theme.retroInk)
                    }

                    Text(streak.metric.prose(streak.threshold, cadence: streak.cadence))
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                        .lineLimit(2)
                }
            }

            HStack {
                Text("TODAY'S CHARGE")
                    .font(RetroFont.pixel(9))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
                Spacer()
                Text(chargeLabel)
                    .font(RetroFont.pixel(9))
                    .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
            }
            .padding(.top, 4)

            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)

            HStack(spacing: 6) {
                Text("best \(streak.best) · ")
                if let s = streak.startDate {
                    Text("since \(DateHelpers.shortDate(s).lowercased())")
                }
            }
            .font(RetroFont.mono(10))
            .foregroundStyle(Theme.retroInkDim)
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta)
    }

    private var chargeLabel: String {
        let v = streak.metric.format(value: streak.currentUnitValue)
        let t = streak.metric.format(value: streak.threshold)
        return "\(v)/\(t) \(streak.metric.unitLabel.uppercased())"
    }

    private var intensity: CGFloat {
        let cap: Double = streak.cadence == .daily ? 30 : 8
        return CGFloat(min(1.0, 0.4 + Double(streak.current) / cap * 0.6))
    }
}
