import SwiftUI

/// Animated flame used behind the hero number.
struct StreakFlame: View {
    var intensity: CGFloat = 1.0
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.streakGradient)
                .blur(radius: 50)
                .opacity(0.55)
                .scaleEffect(1.0 + 0.06 * sin(phase))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.streakGlow.opacity(0.6), .clear],
                        center: .center, startRadius: 10, endRadius: 180
                    )
                )
                .blur(radius: 30)
                .scaleEffect(1.0 + 0.1 * sin(phase * 1.3))
        }
        .opacity(intensity)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                phase = .pi * 4
            }
        }
    }
}
