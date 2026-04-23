import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    enum Step: Int, CaseIterable {
        case intro = 0
        case vibe = 1
        case minimum = 2
        case review = 3
    }

    @State private var step: Step = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil
    @State private var selectedVibe: DiscoveryVibe = .challenging
    @State private var minLength: Int = 0   // 0 = no minimum
    @State private var selectedStreaks: Set<String> = []

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            VStack(spacing: 20) {
                header
                    .padding(.top, 30)
                    .padding(.horizontal, 20)

                switch step {
                case .intro:    introStep
                case .vibe:     vibeStep
                case .minimum:  minimumStep
                case .review:   reviewStep
                }

                Spacer(minLength: 8)

                if let err = errorText {
                    Text(err)
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroRed)
                        .multilineTextAlignment(.center)
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
            ForEach(Step.allCases, id: \.rawValue) { s in
                Rectangle()
                    .fill(s.rawValue <= step.rawValue ? Theme.retroMagenta : Theme.retroInkFaint)
                    .frame(height: 4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step != .intro {
                Button {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .intro }
                } label: {
                    Text("BACK")
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.retroBgRaised)
                        .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await advance() }
            } label: {
                Text(primaryTitle)
                    .font(RetroFont.mono(12, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(requesting)
        }
    }

    private var primaryTitle: String {
        switch step {
        case .intro:    return requesting ? "CONNECTING..." : "▶ CONNECT HEALTH"
        case .vibe:     return "NEXT"
        case .minimum:  return requesting ? "FINDING..." : "▶ FIND MY STREAKS"
        case .review:
            if selectedStreaks.isEmpty { return "PICK AT LEAST ONE" }
            return "▶ START TRACKING (\(selectedStreaks.count))"
        }
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: 18) {
            BlinkingText(text: "▶ INSERT COIN")
                .padding(.top, 6)

            PixelFlame(size: 88, intensity: 1.0, tint: Theme.retroMagenta)

            VStack(spacing: 8) {
                Text("STREAK\nFINDER")
                    .font(RetroFont.mono(26, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .retroGlow(Theme.retroMagenta)

                Text("Discover the fitness streaks\nyou've already built\nfrom Apple Health.")
                    .font(RetroFont.mono(12))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            featurePanel
                .padding(.horizontal, 20)
        }
    }

    private var vibeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICK YOUR VIBE")
                .font(RetroFont.mono(14, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("How do you want your streaks to feel?")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.bottom, 4)

            ForEach(DiscoveryVibe.allCases, id: \.rawValue) { vibe in
                vibeRow(vibe)
            }
        }
        .padding(.horizontal, 20)
    }

    private func vibeRow(_ vibe: DiscoveryVibe) -> some View {
        let selected = selectedVibe == vibe
        let accent: Color = {
            switch vibe {
            case .sustainable: return Theme.retroCyan
            case .challenging: return Theme.retroAmber
            case .lifeChanging: return Theme.retroMagenta
            }
        }()
        return Button {
            selectedVibe = vibe
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(selected ? "◉" : "○")
                    .font(RetroFont.mono(16, weight: .bold))
                    .foregroundStyle(selected ? accent : Theme.retroInkFaint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vibe.label.uppercased())
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? accent : Theme.retroInk)
                    Text(vibe.tagline)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: selected ? accent : Theme.retroInkFaint,
                        fill: selected ? Theme.retroBgCard : Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private var minimumStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MINIMUM LENGTH")
                .font(RetroFont.mono(14, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("Optional. Only show streaks you've kept\ngoing at least this many times.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(minLength == 0 ? "ANY" : "\(minLength)")
                        .font(RetroFont.mono(36, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                        .retroGlow(Theme.retroMagenta)
                    if minLength > 0 {
                        Text("TIMES+")
                            .font(RetroFont.mono(11, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }

                Slider(value: Binding(
                    get: { Double(minLength) },
                    set: { minLength = Int($0.rounded()) }
                ), in: 0...60, step: 1)
                .tint(Theme.retroMagenta)

                HStack {
                    Text("ANY").font(RetroFont.mono(9)).foregroundStyle(Theme.retroInkFaint)
                    Spacer()
                    Text("60+").font(RetroFont.mono(9)).foregroundStyle(Theme.retroInkFaint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .pixelPanel(color: Theme.retroMagenta)

            Text("Tip: \"\(selectedVibe.label)\" vibe will\n\(selectedVibe.tagline.lowercased())")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR STREAKS")
                .font(RetroFont.mono(14, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("We scanned your Apple Health history.\n★ = most interesting for your vibe.\nTap to opt in or out.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

            if store.allCandidates.isEmpty {
                VStack(spacing: 10) {
                    PixelFlame(size: 48, intensity: 0.5, tint: Theme.retroInkDim)
                        .padding(.top, 30)
                    Text("No streaks found yet.\nMove around a bit and refresh.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    StreakPickerList(
                        candidates: store.allCandidates,
                        selection: $selectedStreaks,
                        recommendedCount: min(5, store.allCandidates.count)
                    )
                    .padding(.bottom, 6)
                }
            }
        }
        .padding(.horizontal, 20)
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
        .font(RetroFont.mono(10, weight: .bold))
        .tracking(1)
    }

    // MARK: - Flow

    private func advance() async {
        errorText = nil
        switch step {
        case .intro:
            await requestAuth()
            if errorText == nil {
                withAnimation { step = .vibe }
            }
        case .vibe:
            settings.vibe = selectedVibe
            withAnimation { step = .minimum }
        case .minimum:
            settings.minStreakLength = minLength == 0 ? nil : minLength
            // Discover candidates before showing the review step.
            requesting = true
            // Temporarily clear tracked filter so allCandidates reflects everything.
            settings.trackedStreaks = nil
            await store.load()
            requesting = false
            // Pre-check the top 5 so first-timers aren't staring at an empty selection.
            selectedStreaks = Set(
                store.allCandidates.prefix(5).map {
                    StreakSettings.streakKey(metric: $0.metric, cadence: $0.cadence)
                }
            )
            withAnimation { step = .review }
        case .review:
            guard !selectedStreaks.isEmpty else { return }
            settings.trackedStreaks = selectedStreaks
            store.refilter()
            settings.hasCompletedSetup = true
        }
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
}
