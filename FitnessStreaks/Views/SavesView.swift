import SwiftUI

/// The "Saves" tab. Auto-save status, recent saves, and planned freezes.
/// Kept deliberately light on text: a single animated status panel does the
/// talking, with short data rows below it.
struct SavesView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var storeKit: StoreKitService

    @State private var showingPaywall = false
    @State private var showingFreezeDatePicker = false
    @State private var newFreezeDate = Date()

    private static let freezeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let saveDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusHero
                    if !recentPreservations.isEmpty {
                        savesLog
                    }
                    plannedFreezesCard
                    if !storeKit.isPro {
                        perksStrip
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SAVES")
                        .font(RetroFont.pixel(12))
                        .tracking(2)
                        .foregroundStyle(Theme.retroLime)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "streaks_saves_sheet")
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showingFreezeDatePicker) { freezePicker }
        }
    }

    // MARK: - Status hero

    private var accent: Color { storeKit.isPro ? Theme.retroLime : Theme.retroMagenta }

    private var statusHero: some View {
        VStack(spacing: 16) {
            AutoSavePulse(tint: accent, lit: storeKit.isPro)

            VStack(spacing: 6) {
                Text(storeKit.isPro ? "AUTO-SAVE ON" : "AUTO-SAVE LOCKED")
                    .font(RetroFont.pixel(14))
                    .tracking(2)
                    .foregroundStyle(accent)
                Text(storeKit.isPro
                     ? "Miss a day, keep your streak."
                     : "One miss ends a streak. Streaks+ saves it.")
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                    .multilineTextAlignment(.center)
            }

            if !storeKit.isPro {
                Button {
                    showingPaywall = true
                } label: {
                    Text("START STREAKS+ TRIAL")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.retroMagenta)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start Streaks+ trial")
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: accent, fill: Theme.retroBgRaised)
    }

    // MARK: - Saves log

    private var recentPreservations: [GracePreservation] {
        settings.gracePreservations.values
            .sorted { $0.grantedAt > $1.grantedAt }
    }

    private var savesLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Recent Saves")
            VStack(spacing: 0) {
                ForEach(Array(recentPreservations.prefix(10).enumerated()), id: \.element.key) { idx, p in
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.retroLime)
                        Text("\(p.metric.displayName.uppercased()) · \(p.preservedLength)-DAY RUN")
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroInk)
                        Spacer()
                        Text(Self.saveDateFormatter.string(from: p.grantedAt))
                            .font(RetroFont.mono(9))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    if idx < min(recentPreservations.count, 10) - 1 {
                        Rectangle()
                            .fill(Theme.retroInkFaint.opacity(0.6))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    // MARK: - Planned freezes

    private var plannedFreezesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Planned Freezes")
            if storeKit.isPro {
                proFreezesContent
            } else {
                lockedFreezesContent
            }
        }
    }

    private var proFreezesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Days you mark won't break or extend a streak.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)

            if settings.plannedFreezes.isEmpty {
                Text("No freeze days set.")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkFaint)
                    .padding(.vertical, 6)
            } else {
                ForEach(settings.plannedFreezes.sorted(), id: \.self) { date in
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.retroCyan)
                        Text(Self.freezeDateFormatter.string(from: date))
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInk)
                        Spacer()
                        Button {
                            settings.removeFreezeDay(date)
                            Task { await store.load() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.retroRed)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                newFreezeDate = Date()
                showingFreezeDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("ADD FREEZE DAY")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(Theme.retroCyan)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .pixelPanel(color: Theme.retroCyan)
    }

    private var lockedFreezesContent: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "snowflake")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.retroMagenta)
                Text("Freeze travel or sick days so they never break a streak.")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                Spacer(minLength: 8)
                Text("UNLOCK ›")
                    .font(RetroFont.mono(9, weight: .bold))
                    .foregroundStyle(Theme.retroMagenta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .pixelPanel(color: Theme.retroMagenta)
        }
        .buttonStyle(.plain)
    }

    private var freezePicker: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Pick a day to freeze")
                    .font(RetroFont.mono(14, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                    .padding(.top, 20)

                DatePicker(
                    "Freeze day",
                    selection: $newFreezeDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Theme.retroCyan)
                .padding(.horizontal, 20)

                Button {
                    settings.addFreezeDay(newFreezeDate)
                    showingFreezeDatePicker = false
                    Task { await store.load() }
                } label: {
                    Text("FREEZE THIS DAY")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroBg)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.retroCyan)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CANCEL") { showingFreezeDatePicker = false }
                        .font(RetroFont.mono(10, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }
            }
        }
    }

    // MARK: - Perks strip (free users only)

    private var perksStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "With Streaks+")
            VStack(spacing: 0) {
                perkRow("shield.lefthalf.filled", "Unlimited auto-saves", first: true)
                perkRow("snowflake", "Planned freeze days")
                perkRow("bell.badge.fill", "At-risk alerts")
                perkRow("infinity", "Unlimited streaks")
            }
            .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
        }
    }

    private func perkRow(_ symbol: String, _ title: String, first: Bool = false) -> some View {
        VStack(spacing: 0) {
            if !first {
                Rectangle()
                    .fill(Theme.retroInkFaint.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.retroMagenta)
                    .frame(width: 20)
                Text(title)
                    .font(RetroFont.mono(11, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
        }
    }
}

// MARK: - Auto-save pulse animation

/// Eye-catching status sprite: a breathing pixel flame inside expanding square
/// rings. Driven by a TimelineView tick so the motion never gets eaten by
/// surrounding state animations.
private struct AutoSavePulse: View {
    var tint: Color
    var lit: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = ((t / 2.4) + Double(i) / 3.0)
                        .truncatingRemainder(dividingBy: 1.0)
                    Rectangle()
                        .stroke(tint.opacity(0.55 * (1.0 - phase)), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(0.5 + phase)
                }
                let breathe = 0.9 + 0.1 * sin(t * 2.2)
                PixelFlame(size: 44, intensity: lit ? 1.0 : 0.45, tint: tint)
                    .scaleEffect(breathe)
            }
            .frame(width: 96, height: 96)
        }
        .accessibilityHidden(true)
    }
}
