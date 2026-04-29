import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    enum Phase {
        case intro
        case loading
        case ready
    }

    @State private var phase: Phase = .intro
    @State private var requesting = false
    @State private var errorText: String? = nil
    @State private var loadStartedAt: Date? = nil
    @State private var initialVibe: DiscoveryVibe = .challenging
    @State private var tipIndex: Int = 0
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var flameVisible = true

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
            case .intro:
                introScreen
            case .loading, .ready:
                loadingScreen
            }
        }
        .onReceive(tipTimer) { _ in
            guard phase != .intro else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                tipIndex = (tipIndex + 1) % Self.tips.count
            }
        }
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 30) {
            header
                .padding(.top, 40)
                .padding(.horizontal, 20)

            introStep

            Spacer(minLength: 8)

            if let err = errorText {
                errorBlock(err)
            }

            footer
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

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
                Task { await beginConnect() }
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

    private var introStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "flame.fill")
                .font(.system(size: 88))
                .foregroundStyle(Theme.retroMagenta)
                .retroGlow(Theme.retroMagenta)
                .opacity(flameVisible ? 1 : 0.25)
                .padding(.top, 6)
                .onAppear {
                    withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                        flameVisible = false
                    }
                }

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

    private func errorBlock(_ err: String) -> some View {
        VStack(spacing: 8) {
            Text(err)
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroRed)
                .multilineTextAlignment(.center)
            Button {
                openHealthAccess()
            } label: {
                Text("OPEN HEALTH")
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

    // MARK: - Loading screen

    private var loadingScreen: some View {
        VStack(spacing: 24) {
            header
                .padding(.top, 40)
                .padding(.horizontal, 20)

            VStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
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
            .padding(.top, 4)

            progressBlock
                .padding(.horizontal, 20)

            vibePicker
                .padding(.horizontal, 20)

            tipBlock
                .padding(.horizontal, 20)

            Spacer(minLength: 8)

            continueButton
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
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

    private var vibePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PICK YOUR VIBE")
                .font(RetroFont.mono(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroLime)

            VStack(spacing: 8) {
                ForEach(DiscoveryVibe.allCases, id: \.rawValue) { vibe in
                    vibeRow(vibe)
                }
            }
        }
    }

    private func vibeRow(_ vibe: DiscoveryVibe) -> some View {
        let selected = settings.vibe == vibe
        return Button {
            settings.vibe = vibe
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(selected ? "▶" : " ")
                    .font(RetroFont.mono(12, weight: .bold))
                    .foregroundStyle(Theme.retroLime)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vibe.label.uppercased())
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(selected ? Theme.retroLime : Theme.retroInk)
                    Text(vibe.tagline)
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.retroBgCard : Color.clear)
            .overlay(Rectangle().stroke(selected ? Theme.retroLime : Theme.retroInkFaint, lineWidth: 2))
        }
        .buttonStyle(.plain)
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

    private var continueButton: some View {
        let ready = phase == .ready
        return Button {
            Task { await tapContinue() }
        } label: {
            Text(ready ? "▶ START" : "FINDING STREAKS… \(Int(store.loadProgress * 100))%")
                .font(RetroFont.mono(12, weight: .bold))
                .foregroundStyle(Theme.retroBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ready ? Theme.retroLime : Theme.retroInkFaint)
        }
        .buttonStyle(.plain)
        .disabled(!ready)
    }

    private var currentStageLabel: String {
        if phase == .ready { return "DONE" }
        let label = store.loadStage.label
        return label.isEmpty ? "CONNECTING…" : label
    }

    // MARK: - Flow

    private func beginConnect() async {
        errorText = nil
        await requestAuth()
        guard errorText == nil else { return }

        initialVibe = settings.vibe
        loadStartedAt = .now
        withAnimation { phase = .loading }

        loadTask?.cancel()
        loadTask = Task {
            await store.load()
            await MainActor.run {
                handleLoadFinished()
            }
        }
    }

    private func handleLoadFinished() {
        if store.allCandidates.isEmpty {
            finishEmptySetup()
            return
        }
        let allKeys = store.allCandidates.map(\.trackingKey)
        settings.trackedStreaks = Set(allKeys)
        settings.manualStreakOrder = allKeys
        store.refilter()
        withAnimation { phase = .ready }
    }

    private func tapContinue() async {
        // If the user changed vibe during loading, re-run discovery so the dashboard
        // matches what they picked.
        if settings.vibe != initialVibe {
            initialVibe = settings.vibe
            withAnimation { phase = .loading }
            await store.load()
            handleLoadFinished()
            return
        }
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

    private func finishEmptySetup() {
        settings.trackedStreaks = nil
        store.refilter()
        withAnimation { settings.hasCompletedSetup = true }
    }
}
