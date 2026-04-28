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
        case primary = 4
    }

    @State private var step: Step = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil
    @State private var selectedVibe: DiscoveryVibe = .challenging
    @State private var lookbackDays: Int = 30
    @State private var selectedStreaks: Set<String> = []
    @State private var primaryStreakKey: String? = nil

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
                case .primary:  primaryStep
                }

                Spacer(minLength: 8)

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
                    .background(isPrimaryDisabled ? Theme.retroInkFaint : Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryDisabled)
        }
    }

    private var primaryTitle: String {
        switch step {
        case .intro:    return requesting ? "CONNECTING..." : "▶ CONNECT HEALTH"
        case .vibe:     return "NEXT"
        case .minimum:  return requesting ? "FINDING..." : "▶ FIND MY STREAKS"
        case .review:
            // Empty candidates is the App Store reviewer / fresh-device path:
            // let them finish anyway so the dashboard is reachable.
            if store.allCandidates.isEmpty { return "▶ FINISH SETUP" }
            if selectedStreaks.isEmpty { return "PICK AT LEAST ONE" }
            return "NEXT"
        case .primary:
            return "▶ START TRACKING"
        }
    }

    private var isPrimaryDisabled: Bool {
        if requesting { return true }
        if step == .review && !store.allCandidates.isEmpty && selectedStreaks.isEmpty {
            return true
        }
        if step == .primary && selectedStreaks.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: 18) {
            BlinkingText(text: "▶ INSERT COIN")
                .padding(.top, 6)

            PixelFlame(size: 88, intensity: 1.0, tint: Theme.retroMagenta)

            VStack(spacing: 8) {
                Text("STREAK\nFINDER")
                    .font(RetroFont.mono(32, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .retroGlow(Theme.retroMagenta)
                    .minimumScaleFactor(0.7)

                Text("Discover the fitness streaks\nyou've already built\nfrom Apple Health.")
                    .font(RetroFont.mono(14))
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
                .font(RetroFont.mono(16, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("How do you want your streaks to feel?")
                .font(RetroFont.mono(13))
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
                        .font(RetroFont.mono(14, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? accent : Theme.retroInk)
                    Text(vibe.tagline)
                        .font(RetroFont.mono(13))
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
            Text("DISCOVERY WINDOW")
                .font(RetroFont.mono(16, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("How many days of history should we use\nwhen suggesting new streak thresholds?")
                .font(RetroFont.mono(13))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(lookbackDays)")
                        .font(RetroFont.mono(42, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                        .retroGlow(Theme.retroMagenta)
                    Text("DAYS")
                        .font(RetroFont.mono(13, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                }

                Slider(value: Binding(
                    get: { Double(lookbackDays) },
                    set: { lookbackDays = Int($0.rounded()) }
                ), in: 7...365, step: 1)
                .tint(Theme.retroMagenta)

                HStack {
                    Text("7 DAYS").font(RetroFont.mono(11)).foregroundStyle(Theme.retroInkFaint)
                    Spacer()
                    Text("365 DAYS").font(RetroFont.mono(11)).foregroundStyle(Theme.retroInkFaint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .pixelPanel(color: Theme.retroMagenta)

            Text("Tip: \"\(selectedVibe.label)\" picks goals you\nalready hit \(Int(selectedVibe.targetCompletionRate * 100))% of the time.\nYou choose which ones to track next.")
                .font(RetroFont.mono(13))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR STREAKS")
                .font(RetroFont.mono(16, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("We scanned your Apple Health history.\n★ = most interesting for your vibe.\nPick at least one to start tracking.")
                .font(RetroFont.mono(13))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

            if store.allCandidates.isEmpty {
                VStack(spacing: 10) {
                    PixelFlame(size: 48, intensity: 0.5, tint: Theme.retroInkDim)
                        .padding(.top, 30)
                    Text("No streaks discovered yet.\nFinish setup — Streak Finder will\nsurface them as your Apple Health\nhistory grows.")
                        .font(RetroFont.mono(13))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
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

    private var primaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICK YOUR PRIMARY")
                .font(RetroFont.mono(16, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.retroInk)

            Text("Which streak deserves the top spot?\nThis becomes your hero streak on the dashboard.")
                .font(RetroFont.mono(13))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

            let candidates = store.allCandidates.filter { selectedStreaks.contains($0.trackingKey) }

            if candidates.isEmpty {
                Text("No streaks selected. Go back to pick at least one.")
                    .font(RetroFont.mono(13))
                    .foregroundStyle(Theme.retroRed)
                    .padding(.top, 20)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(candidates) { streak in
                            primaryRow(streak)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func primaryRow(_ streak: Streak) -> some View {
        let selected = primaryStreakKey == streak.trackingKey
        return Button {
            primaryStreakKey = streak.trackingKey
        } label: {
            HStack(spacing: 12) {
                Image(systemName: streak.metric.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(streak.metric.displayName.uppercased())
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? streak.metric.accent : Theme.retroInk)
                    Text(streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence))
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                }
                Spacer()
                Text(selected ? "◉ PRIMARY" : "○")
                    .font(RetroFont.mono(10, weight: .bold))
                    .foregroundStyle(selected ? Theme.retroLime : Theme.retroInkFaint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: selected ? streak.metric.accent : Theme.retroInkFaint,
                        fill: selected ? Theme.retroBgCard : Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private var featurePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            featureRow("8 METRICS · STEPS TO SLEEP")
            featureRow("FITNESS STREAKS FROM HEALTH")
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
            settings.lookbackDays = lookbackDays
            requesting = true
            await store.load()
            requesting = false
            selectedStreaks = []
            withAnimation { step = .review }
        case .review:
            if store.allCandidates.isEmpty {
                finishEmptySetup()
                return
            }
            guard !selectedStreaks.isEmpty else { return }
            settings.trackedStreaks = selectedStreaks
            // Pre-select first selected streak as primary default
            if primaryStreakKey == nil {
                primaryStreakKey = selectedStreaks.sorted().first
            }
            withAnimation { step = .primary }
        case .primary:
            guard !selectedStreaks.isEmpty else { return }
            // Set manual order with primary first
            var order = selectedStreaks.sorted()
            if let primary = primaryStreakKey, let idx = order.firstIndex(of: primary) {
                order.remove(at: idx)
                order.insert(primary, at: 0)
            }
            settings.manualStreakOrder = order
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

    private func finishEmptySetup() {
        settings.trackedStreaks = nil
        store.refilter()
        settings.hasCompletedSetup = true
    }
}
