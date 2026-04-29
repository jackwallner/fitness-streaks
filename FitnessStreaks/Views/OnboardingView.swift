import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    enum Step: Int, CaseIterable {
        case intro = 0
    }

    @State private var step: Step = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            VStack(spacing: 30) {
                header
                    .padding(.top, 40)
                    .padding(.horizontal, 20)

                introStep

                Spacer(minLength: 8)

                if requesting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Theme.retroMagenta)
                        Text("FINDING YOUR STREAKS...")
                            .font(RetroFont.mono(12, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroMagenta)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Theme.retroBgCard)
                    .overlay(Rectangle().stroke(Theme.retroMagenta, lineWidth: 2))
                    .padding(.bottom, 8)
                }

                if let err = errorText {
                    VStack(spacing: 8) {
                        Text(err)
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroRed)
                            .multilineTextAlignment(.center)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("OPEN SETTINGS")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroCyan)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        Button {
                            finishEmptySetup()
                        } label: {
                            Text("SKIP FOR NOW")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroInkDim)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Theme.retroMagenta)
                .frame(height: 4)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                Task { await advance() }
            } label: {
                Text(requesting ? "CONNECTING..." : "▶ CONNECT HEALTH")
                    .font(RetroFont.mono(12, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(requesting ? Theme.retroInkFaint : Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(requesting)
        }
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: 18) {
            BlinkingText(text: "▶ INSERT COIN")
                .padding(.top, 6)

            Image(systemName: "flame.fill")
                .font(.system(size: 88))
                .foregroundStyle(Theme.retroMagenta)
                .retroGlow(Theme.retroMagenta)

            VStack(spacing: 8) {
                Text("STREAK\nFINDER")
                    .font(RetroFont.mono(32, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .retroGlow(Theme.retroMagenta)
                    .minimumScaleFactor(0.7)

                Text("Discover the fitness streaks you've already built.")
                    .font(RetroFont.mono(14))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.retroLime)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRIVATE & SECURE")
                            .font(RetroFont.mono(12, weight: .bold))
                            .foregroundStyle(Theme.retroLime)
                        Text("Streak Finder requires read-only access to Apple Health to calculate your streaks. All data stays 100% local on your device. No networks, no tracking.")
                            .font(RetroFont.mono(11))
                            .foregroundStyle(Theme.retroInkDim)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: Theme.retroLime)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Flow

    private func advance() async {
        errorText = nil
        await requestAuth()
        guard errorText == nil else { return }
        
        requesting = true
        await store.load()
        requesting = false
        
        if store.allCandidates.isEmpty {
            finishEmptySetup()
            return
        }
        
        let allKeys = store.allCandidates.map(\.trackingKey)
        settings.trackedStreaks = Set(allKeys)
        settings.manualStreakOrder = allKeys
        
        store.refilter()
        withAnimation { settings.hasCompletedSetup = true }
    }

    private func requestAuth() async {
        requesting = true
        defer { requesting = false }
        do {
            try await healthKit.requestAuthorization()
        } catch {
            errorText = "Couldn't connect. Open Settings → Health → Data Access → Streak Finder."
        }
    }

    private func finishEmptySetup() {
        settings.trackedStreaks = nil
        store.refilter()
        withAnimation { settings.hasCompletedSetup = true }
    }
}
