import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    @State private var requesting = false
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            VStack(spacing: 24) {
                BlinkingText(text: "▶ INSERT COIN")
                    .padding(.top, 40)

                PixelFlame(size: 96, intensity: 1.0, tint: Theme.retroMagenta)

                VStack(spacing: 10) {
                    Text("STREAK\nFINDER")
                        .font(RetroFont.pixel(22))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .retroGlow(Theme.retroMagenta)

                    Text("Discover the fitness streaks\nyou've already built from\nyour Apple Health data.")
                        .font(RetroFont.mono(12))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                featurePanel
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                if let err = errorText {
                    Text(err)
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                PixelButton(title: requesting ? "LOADING..." : "▶ CONNECT HEALTH",
                            accent: Theme.retroLime) {
                    Task { await onStart() }
                }
                .disabled(requesting)
                .padding(.horizontal, 20)

                Text("READ-ONLY ACCESS · V1.0.0")
                    .font(RetroFont.pixel(8))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkFaint)
                    .padding(.bottom, 24)
            }
        }
    }

    private var featurePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            featureRow("9 METRICS · STEPS TO SLEEP")
            featureRow("DAILY & WEEKLY STREAKS")
            featureRow("CALENDAR HEATMAPS")
            featureRow("100% LOCAL · NO NETWORK")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroCyan)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text("▸").foregroundStyle(Theme.retroCyan)
            Text(text).foregroundStyle(Theme.retroInk)
        }
        .font(RetroFont.pixel(10))
        .tracking(1)
    }

    private func onStart() async {
        requesting = true
        defer { requesting = false }
        errorText = nil
        do {
            try await healthKit.requestAuthorization()
            settings.hasCompletedSetup = true
            await store.load()
        } catch {
            errorText = "Couldn't connect. Try Settings → Health → Data Access → Streak Finder."
        }
    }
}
