import SwiftUI

struct StreakHero: View {
    let streak: Streak

    var body: some View {
        ZStack {
            StreakFlame(intensity: intensity)
                .frame(height: 340)
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Image(systemName: streak.metric.symbol)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.streakGradient)
                    .padding(.bottom, 4)

                Text("\(streak.current)")
                    .font(Theme.bigNumber(120))
                    .foregroundStyle(Theme.streakGradient)
                    .shadow(color: Theme.streakHot.opacity(0.35), radius: 14, y: 4)

                Text(streak.cadence == .daily
                     ? (streak.current == 1 ? "day streak" : "day streak")
                     : (streak.current == 1 ? "week streak" : "week streak"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.lowercase)

                Text(streak.metric.prose(streak.threshold, cadence: streak.cadence))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var intensity: CGFloat {
        // Ramp up as the streak grows; cap at 1.0 around 30+ days / 8+ weeks.
        let cap: Double = streak.cadence == .daily ? 30 : 8
        return CGFloat(min(1.0, 0.4 + Double(streak.current) / cap * 0.6))
    }
}
