import SwiftUI
import RevenueCatUI

/// The "Saves" tab — Pro's home turf. Shows auto-save status, recent saves history,
/// planned freezes, and the upgrade pitch. The Pro features story lives here so the
/// Streaks tab can stay focused on actual streaks.
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
                VStack(alignment: .leading, spacing: 20) {
                    autoSaveHero
                    if !recentPreservations.isEmpty {
                        savesLog
                    }
                    plannedFreezesCard
                    if !storeKit.isPro {
                        proPitchFooter
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
                if let offering = storeKit.offerings?.current {
                    PaywallView(offering: offering)
                        .interactiveDismissDisabled(true)
                } else {
                    PaywallView()
                        .interactiveDismissDisabled(true)
                }
            }
            .sheet(isPresented: $showingFreezeDatePicker) { freezePicker }
        }
    }

    // MARK: - Auto-save hero

    private var autoSaveHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PixelFlame(size: 48, intensity: 0.7, tint: storeKit.isPro ? Theme.retroLime : Theme.retroMagenta)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(storeKit.isPro ? "AUTO-SAVE ON" : "AUTO-SAVE LOCKED")
                            .font(RetroFont.pixel(11))
                            .tracking(2)
                            .foregroundStyle(storeKit.isPro ? Theme.retroLime : Theme.retroMagenta)
                        if storeKit.isPro {
                            PixelChip(text: "PRO", accent: Theme.retroLime)
                        }
                    }
                    Text(storeKit.isPro
                         ? "Miss a day, keep your streak. Unlimited."
                         : "One miss ends your streak.")
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroInk)
                }
                Spacer(minLength: 0)
            }

            Text(storeKit.isPro
                 ? "Pro saves every missed day automatically — your streak keeps growing through travel, sick days, and life. No grace days to ration, no manual taps."
                 : "Free streaks die on the first miss. Pro auto-saves every miss so the count keeps climbing. Travel, sick days, life — Pro doesn't care.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(3)

            if !storeKit.isPro {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Text("UNLOCK PRO")
                            .font(RetroFont.mono(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Theme.retroBg)
                        Spacer()
                        Text("›")
                            .font(RetroFont.mono(14, weight: .bold))
                            .foregroundStyle(Theme.retroBg)
                    }
                    .padding(14)
                    .background(Theme.retroMagenta)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock FitnessStreaks Pro")
            }
        }
        .padding(16)
        .pixelPanel(color: storeKit.isPro ? Theme.retroLime : Theme.retroMagenta, fill: Theme.retroBgRaised)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(p.metric.displayName.uppercased()) · \(p.preservedLength)-DAY RUN")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Text("Saved \(Self.saveDateFormatter.string(from: p.grantedAt))")
                                .font(RetroFont.mono(9))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        Spacer()
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
            Text("Mark days you know you'll miss (vacation, travel, sick). Freeze days don't break streaks or extend them.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .lineSpacing(2)

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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.retroMagenta)
                    PixelChip(text: "PRO", accent: Theme.retroMagenta)
                    Spacer()
                    Text("UNLOCK →")
                        .font(RetroFont.mono(9, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }

                Text("Planned freezes let you mark vacation, travel, or sick days so they don't break your streaks.")
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
                    .lineSpacing(2)

                if !settings.plannedFreezes.isEmpty {
                    Text("\(settings.plannedFreezes.count) freeze day\(settings.plannedFreezes.count == 1 ? "" : "s") set")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkFaint)
                }
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

    // MARK: - Pro pitch footer (free users only)

    private var proPitchFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelSectionHeader(title: "What you get with Pro")
            VStack(alignment: .leading, spacing: 10) {
                pitchRow(symbol: "shield.lefthalf.filled",
                         title: "UNLIMITED AUTO-SAVES",
                         body: "Every missed day gets saved automatically.")
                pitchRow(symbol: "snowflake",
                         title: "UNLIMITED PLANNED FREEZES",
                         body: "Travel, sick, on holiday — schedule it.")
                pitchRow(symbol: "bell.badge.fill",
                         title: "PROACTIVE AT-RISK ALERTS",
                         body: "Daily nudge before the day gets away.")
                pitchRow(symbol: "plus.square",
                         title: "UNLIMITED CUSTOM STREAKS",
                         body: "Free is capped at 3. Pro removes the cap.")
            }
            .padding(14)
            .pixelPanel(color: Theme.retroMagenta, fill: Theme.retroBgRaised)
        }
    }

    private func pitchRow(symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.retroMagenta)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RetroFont.pixel(10))
                    .tracking(1)
                    .foregroundStyle(Theme.retroInk)
                Text(body)
                    .font(RetroFont.mono(10))
                    .foregroundStyle(Theme.retroInkDim)
            }
        }
    }
}
