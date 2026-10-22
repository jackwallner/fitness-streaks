import SwiftUI

enum RootTab: Hashable {
    case streaks, saves, stats
}

/// The trailing pane of the unfolded iPhone Duo. Rows that would push a streak
/// (or the gear that would present Settings) open it here instead. `nil` in
/// the environment means there is no pane: push and present as on a phone.
struct StreakDetailPane {
    /// The streak on show, `nil` when there is none.
    var selectedKey: String?
    var showsSettings: Bool
    var open: @MainActor (Streak) -> Void
    var openSettings: @MainActor () -> Void
}

private struct StreakDetailPaneKey: EnvironmentKey {
    static var defaultValue: StreakDetailPane? { nil }
}

extension EnvironmentValues {
    var streakDetailPane: StreakDetailPane? {
        get { self[StreakDetailPaneKey.self] }
        set { self[StreakDetailPaneKey.self] = newValue }
    }
}

struct RootTabView: View {
    @EnvironmentObject var store: StreakStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selection: RootTab = .streaks
    /// Measured so the unfolded iPhone Duo can put the tabs and the streak
    /// they open on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry(width: 0, fold: nil)
    @State private var paneStreakKey: String?
    @State private var paneShowsSettings = false

    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// The pane's streak, falling back to the hero when it is untracked.
    private var paneStreak: Streak? {
        store.streaks.first { $0.trackingKey == paneStreakKey } ?? store.hero
    }

    var body: some View {
        // One view tree in every pose: opening or closing the Duo only moves
        // these frames, so the open tab keeps its scroll position.
        ZStack(alignment: .bottomLeading) {
            content
                .padding(.bottom, 64)  // leave room for the pixel tab bar
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)

            PixelTabBar(selection: $selection)
                // Within the leading pane while split, never across the fold.
                .frame(maxWidth: split?.primaryWidth ?? .infinity)

            if let split {
                detailPane
                    .frame(maxWidth: split.secondaryWidth, maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .horizontalToolbarsInPanes(split != nil)
        .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
        .environment(\.streakDetailPane, split == nil ? nil : StreakDetailPane(
            selectedKey: paneStreak?.trackingKey,
            showsSettings: paneShowsSettings,
            open: { streak in
                paneShowsSettings = false
                paneStreakKey = streak.trackingKey
            },
            openSettings: { paneShowsSettings = true }
        ))
        .background(Theme.retroBg.ignoresSafeArea())
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .onChange(of: split != nil) { _, isSplit in
            // Folding hands Settings back to the Dashboard's sheet.
            if !isSplit { paneShowsSettings = false }
        }
        #if DEBUG
        .task(id: split != nil) { await runDuoTour(split: split != nil) }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .streaks: DashboardView()
        case .saves:   SavesView()
        case .stats:   StatsView()
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if paneShowsSettings {
            SettingsView(onClose: { paneShowsSettings = false })
        } else if let streak = paneStreak {
            NavigationStack {
                StreakDetailView(streak: streak, isPane: true)
            }
            .id(streak.trackingKey)
        } else {
            VStack(spacing: 14) {
                PixelFlame(size: 56, intensity: 0.5, tint: Theme.retroInkDim)
                Text("PICK A STREAK")
                    .font(RetroFont.mono(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    #if DEBUG
    /// See `DuoScreenshotTour`. Each route starts with Settings closed.
    private func runDuoTour(split isSplit: Bool) async {
        guard DuoScreenshotTour.isEnabled else { return }
        try? await Task.sleep(for: .seconds(DuoScreenshotTour.firstDelay))
        while !Task.isCancelled {
            for route in DuoScreenshotTour.routes(split: isSplit) {
                guard !Task.isCancelled else { return }
                NSLog("DUOTOUR %@ route=%@", isSplit ? "inner" : "outer", route)
                NSLog("DUOGEOM root=%.1f fold=%@ split=%@", paneGeometry.width,
                      String(describing: paneGeometry.fold), String(describing: split))
                withAnimation(.easeInOut(duration: 0.3)) { openDuoRoute(route) }
                try? await Task.sleep(for: .seconds(DuoScreenshotTour.step))
            }
        }
    }

    private func openDuoRoute(_ route: String) {
        let parts = route.split(separator: "/").map(String.init)
        switch parts.first ?? "" {
        case "saves": selection = .saves
        case "stats": selection = .stats
        default: selection = .streaks
        }
        paneShowsSettings = parts.last == "settings"
        if parts.count > 1, let metric = StreakMetric(rawValue: parts[1]) {
            paneStreakKey = store.streaks.first { $0.metric == metric }?.trackingKey
        } else {
            paneStreakKey = nil
        }
    }
    #endif
}

#if DEBUG
/// Unattended iPhone Duo capture (`gh-sim launch --device 'iPhone Duo'`).
///
/// `-DuoTour` walks the tabs on a timer, because `simctl openurl` raises a
/// confirmation alert the capture job cannot tap. A route is a tab
/// (`streaks`, `stats`, `saves`), optionally followed by the metric the
/// trailing pane shows (`stats/standHours`) or `settings`. `-DuoRoutes` is the
/// walk while folded and `-DuoRoutesRegular` while split. `-DuoTourFirst <s>`
/// is the delay before the first route and `-DuoTourStep <s>` the dwell on
/// each. The walk loops and restarts when the panes split or join. Every step
/// logs a `DUOTOUR` line, which maps the captures to routes.
enum DuoScreenshotTour {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool { arguments.contains("-DuoTour") }

    static func routes(split: Bool) -> [String] {
        let list = value(split ? "-DuoRoutesRegular" : "-DuoRoutes")
            ?? (split
                ? "streaks,streaks/exerciseMinutes,stats/standHours,saves/sleepHours,streaks/settings"
                : "streaks,stats,saves")
        return list.split(separator: ",").map(String.init)
    }

    static var firstDelay: Double { value("-DuoTourFirst").flatMap(Double.init) ?? 2 }
    static var step: Double { value("-DuoTourStep").flatMap(Double.init) ?? 10 }

    private static func value(_ key: String) -> String? {
        guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }
}
#endif

private struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat
    var fold: ClosedRange<CGFloat>?
}

private extension View {
    /// iOS 27.1 moves a stack's toolbar into a vertical bar on its trailing
    /// edge, which in the leading pane sits against the fold and narrowed the
    /// tabs by 84 pt. While split each pane keeps the phone's horizontal bar
    /// and the status bar runs across the top of the trailing pane. Folded,
    /// the system default is unchanged.
    @ViewBuilder
    func horizontalToolbarsInPanes(_ isSplit: Bool) -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(isSplit ? .disabled : .automatic)
        } else {
            self
        }
    }
}

private extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

private struct PixelTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 0) {
            tab(.streaks, label: "STREAKS", symbol: "flame.fill", accent: Theme.retroMagenta)
            tab(.saves,   label: "SAVES",   symbol: "shield.lefthalf.filled", accent: Theme.retroLime)
            tab(.stats,   label: "STATS",   symbol: "chart.bar.fill", accent: Theme.retroCyan)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            Rectangle()
                .fill(Theme.retroBg)
                .overlay(
                    Rectangle()
                        .fill(Theme.retroInkFaint)
                        .frame(height: 2),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ tab: RootTab, label: String, symbol: String, accent: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selection == tab ? accent : Theme.retroInkDim)
                Text(label)
                    .font(RetroFont.pixel(8))
                    .tracking(1)
                    .foregroundStyle(selection == tab ? accent : Theme.retroInkDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                if selection == tab {
                    Rectangle()
                        .fill(accent)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.capitalized)
    }
}
