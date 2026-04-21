import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    @State private var requesting = false
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        StreakFlame(intensity: 0.9)
                            .frame(height: 220)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 88, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.streakGradient)
                            .shadow(color: Theme.streakHot.opacity(0.4), radius: 18)
                    }

                    Text("Fitness Streaks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("See the fitness streaks you've already built.\nAnd keep them going.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 14) {
                    if let err = errorText {
                        Text(err)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        Task { await onStart() }
                    } label: {
                        HStack {
                            if requesting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Connect Apple Health")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.streakGradient, in: Capsule())
                        .padding(.horizontal, 24)
                    }
                    .disabled(requesting)

                    Text("Reads activity history only. Never writes.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.bottom, 40)
            }
        }
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
            errorText = "Couldn't connect to Apple Health. Open Settings → Health → Data Access & Devices → Fitness Streaks."
        }
    }
}
