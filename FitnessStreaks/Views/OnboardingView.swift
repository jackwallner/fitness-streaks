import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    enum Phase {
        case intro       // welcome + privacy + Connect Health
        case intensity   // pick discovery intensity (after auth)
        case loading     // running discovery
        case selecting   // pick which discovered streaks to track
        case empty       // no streaks discovered
    }

    @State private var phase: Phase = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil
    @State private var tipIndex: Int = 0
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var flameVisible = true
    @State private var selection: Set<String> = []

    private static let tips: [String] = [
        "Streaks update automatically from Apple Health — no manual logging.",
        "Sleep streaks are credited to the day a sleep sample ends.",
        "Weekly streaks reset on Mondays, ISO-style.",
        "Today doesn't break your streak until the day actually ends.",
        "Add the widget for a glanceable streak count on your home screen.",
        "Per-workout-type streaks let you track yoga, runs, and lifts separately."
    ]

    private let tipTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            switch phase {
            case .intro:     introScreen
            case .intensity: intensityScreen
            case .loading:   loadingScreen
            case .selecting: selectingScreen
            case .empty:     emptyScreen
            }
        }
        .onReceive(tipTimer) { _ in
            guard phase == .loading else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                tipIndex = (tipIndex + 1) % Self.tips.count
            }
        }
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 18) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                    .opacity(flameVisible ? 1 : 0.25)
                    .padding(.top, 30)
                    .onAppear {
                        withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                            flameVisible = false
                        }
                    }

                VStack(spacing: 10) {
                    Text("STREAK\nFINDER")
                        .font(RetroFont.mono(32, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .retroGlow(Theme.retroMagenta)
                        .minimumScaleFactor(0.7)

                    Text("Discover the fitness streaks you've already built.")
                        .font(RetroFont.mono(13))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                privacyPanel
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            if let err = errorText {
                errorBlock(err)
            }

            connectButton
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var privacyPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.retroLime)
            VStack(alignment: .leading, spacing: 4) {
                Text("PRIVATE & SECURE")
                    .font(RetroFont.mono(12, weight: .bold))
                    .foregroundStyle(Theme.retroLime)
                Text("Read-only access to Apple Health. Everything stays on your device — no networks, no tracking.")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroLime)
    }

    private var connectButton: some View {
        Button {
            Task { await beginConnect() }
        } label: {
            Text(requesting ? "CONNECTING..." : "▶ CONNECT HEALTH")
                .font(RetroFont.mono(13, weight: .bold))
                .foregroundStyle(Theme.retroBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(requesting ? Theme.retroInkFaint : Theme.retroLime)
        }
        .buttonStyle(.plain)
        .disabled(requesting)
    }

    private func errorBlock(_ err: String) -> some View {
        VStack(spacing: 8) {
            Text(err)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroRed)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button {
                    openHealthAccess()
                } label: {
                    Text("OPEN HEALTH")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)
                Button {
                    finishWithoutTracking()
                } label: {
                    Text("SKIP")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Intensity

    private var intensityScreen: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("PICK YOUR INTENSITY")
                    .font(RetroFont.mono(22, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                Text("How hard should your streaks push you?")
                    .font(RetroFont.mono(12))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                ForEach(DiscoveryIntensity.allCases, id: \.rawValue) { intensity in
                    intensityRow(intensity)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)

            Button {
                startDiscovery()
            } label: {
                Text("▶ FIND MY STREAKS")
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.retroLime)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func intensityRow(_ intensity: DiscoveryIntensity) -> some View {
        let selected = settings.intensity == intensity
        return Button {
            settings.intensity = intensity
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(selected ? "▶" : " ")
                    .font(RetroFont.mono(14, weight: .bold))
                    .foregroundStyle(Theme.retroLime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(intensity.label.uppercased())
                        .font(RetroFont.mono(13, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? Theme.retroLime : Theme.retroInk)
                    Text(intensity.tagline)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.retroBgCard : Color.clear)
            .overlay(Rectangle().stroke(selected ? Theme.retroLime : Theme.retroInkFaint, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading

    private var loadingScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)

                Text("FINDING YOUR\nSTREAKS")
                    .font(RetroFont.mono(22, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .retroGlow(Theme.retroMagenta)
            }
            .padding(.top, 24)

            progressBlock
                .padding(.horizontal, 20)

            tipBlock
                .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentStageLabel)
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroCyan)
                Spacer()
                Text("\(Int(store.loadProgress * 100))%")
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroCyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.retroBgCard)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                    Rectangle()
                        .fill(Theme.retroCyan)
                        .frame(width: max(0, geo.size.width * CGFloat(store.loadProgress)))
                        .padding(2)
                }
            }
            .frame(height: 18)
        }
    }

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DID YOU KNOW")
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroMagenta)
            Text(Self.tips[tipIndex])
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(tipIndex)
                .transition(.opacity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroMagenta)
    }

    private var currentStageLabel: String {
        let label = store.loadStage.label
        return label.isEmpty ? "CONNECTING…" : label
    }

    // MARK: - Selecting

    private var selectingScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("YOUR STREAKS")
                    .font(RetroFont.mono(20, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                    .retroGlow(Theme.retroMagenta)
                Text("\(store.allCandidates.count) discovered · pick the ones you want to track")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            HStack(spacing: 10) {
                Text("\(selection.count) SELECTED")
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroLime)
                Spacer()
                Button { selection = Set(store.allCandidates.map(\.trackingKey)) } label: {
                    Text("SELECT ALL")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            ScrollView {
                StreakPickerList(
                    candidates: store.allCandidates,
                    selection: $selection,
                    recommendedCount: min(5, store.allCandidates.count)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }

            Button {
                finishWithSelection()
            } label: {
                Text(selection.isEmpty ? "PICK AT LEAST ONE" : "▶ START · \(selection.count) STREAK\(selection.count == 1 ? "" : "S")")
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selection.isEmpty ? Theme.retroInkFaint : Theme.retroLime)
            }
            .buttonStyle(.plain)
            .disabled(selection.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Empty

    private var emptyScreen: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "flame")
                .font(.system(size: 72))
                .foregroundStyle(Theme.retroInkDim)

            VStack(spacing: 10) {
                Text("NO STREAKS YET")
                    .font(RetroFont.mono(20, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroMagenta)
                Text("We didn't find any active streaks in your Apple Health history. Once you log a few days of activity, we'll surface them here.")
                    .font(RetroFont.mono(12))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)

            Button {
                finishWithoutTracking()
            } label: {
                Text("▶ CONTINUE")
                    .font(RetroFont.mono(13, weight: .bold))
                    .foregroundStyle(Theme.retroBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.retroLime)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Flow

    private func beginConnect() async {
        errorText = nil
        await requestAuth()
        guard errorText == nil else { return }
        withAnimation { phase = .intensity }
    }

    private func startDiscovery() {
        withAnimation { phase = .loading }
        loadTask?.cancel()
        loadTask = Task {
            await store.load()
            await MainActor.run { handleLoadFinished() }
        }
    }

    private func handleLoadFinished() {
        if store.allCandidates.isEmpty {
            withAnimation { phase = .empty }
            return
        }
        // Pre-select all discovered streaks; user can prune. Engine already ranked them by vibe.
        selection = Set(store.allCandidates.map(\.trackingKey))
        withAnimation { phase = .selecting }
    }

    private func finishWithSelection() {
        guard !selection.isEmpty else { return }
        settings.trackedStreaks = selection
        // Manual order = engine order, filtered to selection (preserves intensity ranking).
        // Then prefer steps-daily as the primary if it's in the selected set — most users
        // expect their step streak to be the headline, not whatever the engine ranked first.
        var order = store.allCandidates
            .map(\.trackingKey)
            .filter { selection.contains($0) }
        let stepsKey = StreakSettings.streakKey(metric: .steps, cadence: .daily)
        if let idx = order.firstIndex(of: stepsKey), idx != 0 {
            order.remove(at: idx)
            order.insert(stepsKey, at: 0)
        }
        settings.manualStreakOrder = order
        store.refilter()
        withAnimation { settings.hasCompletedSetup = true }
    }

    private func finishWithoutTracking() {
        settings.trackedStreaks = nil
        store.refilter()
        withAnimation { settings.hasCompletedSetup = true }
    }

    private func requestAuth() async {
        requesting = true
        defer { requesting = false }
        do {
            try await healthKit.requestAuthorization()
        } catch {
            errorText = "Couldn't connect. Open Health → Sharing → Apps → Streak Finder and turn on access."
        }
    }

    private func openHealthAccess() {
        if let url = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
