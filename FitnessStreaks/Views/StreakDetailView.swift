import SwiftUI

struct StreakDetailView: View {
    let initialStreak: Streak
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @State private var actionMessage: String? = nil
    @State private var isRecalibrating = false

    @State private var showingRecalibrateConfirm = false
    @State private var showingCustomBuilder = false
    @State private var showingUntrackConfirm = false
    @State private var selectedHeatmapRange: HeatmapDateRange

    init(streak: Streak) {
        self.initialStreak = streak
        // Pick a heatmap range that comfortably covers the user's recent history.
        // We can't read settings here, so default to 90d — refined onAppear.
        _selectedHeatmapRange = State(initialValue: .last90Days)
    }

    /// Always render against the freshest version of the streak from the store
    /// so recalibration / threshold changes update the UI immediately.
    private var streak: Streak {
        store.streaks.first { $0.trackingKey == initialStreak.trackingKey } ?? initialStreak
    }

    var isHero: Bool { store.hero?.id == streak.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard.padding(.horizontal, 14)
                if let actionMessage { statusCard(actionMessage).padding(.horizontal, 14) }
                quickActionsCard.padding(.horizontal, 14)

                if streak.window != nil {
                    hourWindowExplainer.padding(.horizontal, 14)
                    statsRow.padding(.horizontal, 14)
                } else {
                    PixelSectionHeader(title: "HISTORY")
                        .padding(.top, 4)

                    heatmapCard.padding(.horizontal, 14)
                    statsRow.padding(.horizontal, 14)
                }
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            selectedHeatmapRange = HeatmapDateRange.defaultFor(lookbackDays: settings.lookbackDays)
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if !isLoading, isRecalibrating {
                isRecalibrating = false
                let refreshed = store.streaks.first { $0.trackingKey == initialStreak.trackingKey } ?? initialStreak
                actionMessage = "Recalibration complete. New goal: \(refreshed.thresholdLabel)."
            }
        }
        .background(Theme.retroBg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(RetroFont.mono(10, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("DETAIL")
                    .font(RetroFont.pixel(9))
                    .tracking(3)
                    .foregroundStyle(Theme.retroInkFaint)
            }
        }
        .toolbarBackground(Theme.retroBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(toolbarTitle)
                        .font(RetroFont.mono(18, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.metric.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(headerProse)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: streak.displaySymbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(streak.metric.accent)
                    .shadow(color: streak.metric.accent.opacity(0.6), radius: 10)
                    .frame(width: 36, height: 36)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(streak.format(currentUnitValue: streak.currentUnitValue))
                        .font(RetroFont.mono(42, weight: .bold))
                        .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent)
                        .retroGlow(streak.currentUnitCompleted ? Theme.retroLime : streak.metric.accent)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                    Text(streak.unitLabel.uppercased())
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(Theme.retroInkDim)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("GOAL")
                        .font(RetroFont.mono(8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Text(headerGoalValue.uppercased())
                        .font(RetroFont.mono(11, weight: .bold))
                        .foregroundStyle(streak.metric.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(streak.cadence == .daily ? "TODAY" : "THIS WEEK")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                    Spacer(minLength: 0)
                    Text(streak.currentUnitCompleted ? "DONE" : "\(Int(min(1, streak.currentUnitProgress) * 100))%")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
                }
                PixelProgressBar(progress: streak.currentUnitProgress,
                                 accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
            }

            HStack(spacing: 8) {
                statPill(value: "\(streak.current)", label: streak.current == 1 ? "\(streak.cadence.label) streak" : "\(streak.cadence.pluralLabel) streak", color: streak.metric.accent)
                statPill(value: "\(streak.best)", label: streak.best == 1 ? "best \(streak.cadence.label)" : "best \(streak.cadence.pluralLabel)", color: Theme.retroAmber)
            }

            if let lastMissed = streak.lastMissedDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.retroInkDim)
                    Text("Last missed: \(formatDate(lastMissed)) (\(formatDayOfWeek(lastMissed)))")
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: streak.metric.accent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak.metric.displayName) streak: \(streak.current) \(streak.cadence.pluralLabel) in a row, threshold \(Int(streak.threshold)) \(streak.metric.unitLabel)")
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(RetroFont.mono(18, weight: .bold))
                .foregroundStyle(color)
                .retroGlow(color, radius: 6)
            Text(label.uppercased())
                .font(RetroFont.mono(9, weight: .bold))
                .foregroundStyle(Theme.retroInkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.retroBgCard)
    }

    private var toolbarTitle: String {
        if let w = streak.window {
            return "\(streak.displayName.uppercased()) · \(w.label.uppercased())"
        }
        return streak.displayName.uppercased()
    }

    private var headerProse: String {
        if let w = streak.window {
            let t = streak.metric.format(value: streak.threshold)
            return "\(t)+ \(streak.metric.unitLabel) every day between \(w.label)"
        }
        return streak.prose
    }

    private var headerGoalValue: String {
        "\(streak.format(currentUnitValue: streak.threshold)) \(streak.unitLabel)"
    }

    // MARK: - Hour-window explainer

    private var hourWindowExplainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Theme.retroAmber)
                Text("TIME-OF-DAY RHYTHM")
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.retroAmber)
            }
            Text("Streak Finder spotted a hidden pattern: you consistently hit this target within a single hour of the day. Keep it alive — the next window starts at \(streak.window?.label ?? "").")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroAmber)
    }

    // MARK: - Today card

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY")
                    .font(RetroFont.pixel(9))
                    .tracking(2)
                    .foregroundStyle(Theme.retroInkDim)
                Spacer()
                if streak.currentUnitCompleted {
                    Text("✓ DONE")
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroLime)
                } else {
                    Text("\(Int(min(1, streak.currentUnitProgress) * 100))%")
                        .font(RetroFont.pixel(9))
                        .foregroundStyle(Theme.retroAmber)
                }
            }
            PixelProgressBar(progress: streak.currentUnitProgress,
                             accent: streak.currentUnitCompleted ? Theme.retroLime : Theme.retroAmber)
        }
        .padding(14)
        .pixelPanel(color: Theme.retroAmber)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's progress: \(Int(min(1, streak.currentUnitProgress) * 100)) percent. \(streak.currentUnitCompleted ? "Goal complete." : "Goal not yet complete.")")
    }

    private func statusCard(_ text: String) -> some View {
        Text(text)
            .font(RetroFont.mono(11, weight: .bold))
            .foregroundStyle(Theme.retroLime)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: Theme.retroLime, fill: Theme.retroBg)
    }

    private var canRecalibrate: Bool {
        streak.customID == nil && settings.committedThresholds[streak.trackingKey] != nil
    }

    private var recalibrateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCKED GOAL")
                        .font(RetroFont.pixel(9))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkDim)
                    Text(recalibrationPreview)
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                }
                Spacer()
                Button {
                    showingRecalibrateConfirm = true
                } label: {
                    Text("RECALIBRATE")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recalibrate threshold from Apple Health")
                .alert("Recalibrate Goal?", isPresented: $showingRecalibrateConfirm) {
                    Button("Recalibrate (Apple Health)", role: .destructive) {
                        settings.clearCommittedThreshold(for: streak.trackingKey)
                        isRecalibrating = true
                        actionMessage = "Recalibrating from Apple Health..."
                        Task { await store.load() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure? This will update your goal based on recent activity. If the new goal is higher, you might lose your streak.")
                }
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroCyan)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIONS")
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroInkDim)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    if !isHero {
                        compactActionButton(title: "PRIMARY", color: Theme.retroMagenta) {
                            makePrimary()
                        }
                    }
                    if canRecalibrate {
                        compactActionButton(title: "RECALIBRATE", color: Theme.retroCyan) {
                            showingRecalibrateConfirm = true
                        }
                    }
                    compactActionButton(title: "UNTRACK", color: Theme.retroRed) {
                        showingUntrackConfirm = true
                    }
                }

                VStack(spacing: 8) {
                    if !isHero {
                        compactActionButton(title: "MAKE PRIMARY", color: Theme.retroMagenta) {
                            makePrimary()
                        }
                    }
                    if canRecalibrate {
                        compactActionButton(title: "RECALIBRATE", color: Theme.retroCyan) {
                            showingRecalibrateConfirm = true
                        }
                    }
                    compactActionButton(title: "UNTRACK", color: Theme.retroRed) {
                        showingUntrackConfirm = true
                    }
                }
            }
            .alert("Recalibrate Goal?", isPresented: $showingRecalibrateConfirm) {
                Button("Recalibrate (Apple Health)", role: .destructive) {
                    settings.clearCommittedThreshold(for: streak.trackingKey)
                    Task { await store.load() }
                    actionMessage = "Recalibrating from Apple Health..."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This re-analyzes your last \(settings.lookbackDays) days of activity and may suggest a different goal than your current \(streak.thresholdLabel). If the new goal is higher than your recent activity, your streak may break.")
            }
            .alert("Untrack this streak?", isPresented: $showingUntrackConfirm) {
                Button("Untrack", role: .destructive) { untrack() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It will disappear from your dashboard. Your Apple Health history is unchanged — you can re-add it from Settings → Tracked Streaks.")
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroInkFaint)
    }

    private func compactActionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.mono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .overlay(Rectangle().stroke(color, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var makePrimaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MAKE THIS YOUR PRIMARY")
                        .font(RetroFont.pixel(9))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkDim)
                    Text("Move to top of dashboard")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                }
                Spacer()
                Button {
                    makePrimary()
                } label: {
                    Text("MAKE PRIMARY")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroMagenta)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .overlay(Rectangle().stroke(Theme.retroMagenta, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Make this the primary streak on the dashboard")
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroMagenta)
    }

    private var untrackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNTRACK STREAK")
                        .font(RetroFont.pixel(9))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkDim)
                    Text("Remove from your dashboard")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInk)
                }
                Spacer()
                Button {
                    showingUntrackConfirm = true
                } label: {
                    Text("UNTRACK")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroRed)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .overlay(Rectangle().stroke(Theme.retroRed, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Untrack this streak")
                .alert("Untrack this streak?", isPresented: $showingUntrackConfirm) {
                    Button("Untrack", role: .destructive) { untrack() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("It will disappear from your dashboard. Your Apple Health history is unchanged — you can re-add it from Settings → Tracked Streaks.")
                }
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroRed)
    }

    private func untrack() {
        var tracked = settings.trackedStreaks ?? Set(store.allCandidates.map(\.trackingKey))
        tracked.remove(streak.trackingKey)
        settings.trackedStreaks = tracked
        settings.manualStreakOrder.removeAll { $0 == streak.trackingKey }
        settings.recentlyBroken.removeAll { $0.key == streak.trackingKey }
        store.refilter()
        dismiss()
    }

    private func makePrimary() {
        // Move this streak to front of manual order
        var newOrder = settings.manualStreakOrder.filter { $0 != streak.trackingKey }
        newOrder.insert(streak.trackingKey, at: 0)
        settings.manualStreakOrder = newOrder
        // Ensure it's tracked
        if var tracked = settings.trackedStreaks {
            tracked.insert(streak.trackingKey)
            settings.trackedStreaks = tracked
        }
        store.refilter()
        actionMessage = "Primary streak updated."
    }

    private var recalibrationPreview: String {
        guard let suggested = suggestedThreshold else {
            return "Currently \(streak.thresholdLabel)"
        }
        return "Currently \(streak.thresholdLabel) → suggests \(streak.metric.thresholdLabel(suggested, cadence: streak.cadence))"
    }

    private var suggestedThreshold: Double? {
        if streak.window != nil { return nil }
        let candidates = StreakEngine.discover(
            history: store.history,
            hourlySteps: store.hourlySteps,
            hiddenMetrics: settings.hiddenMetrics,
            intensity: settings.intensity,
            lookbackDays: settings.lookbackDays,
            committedThresholds: settings.committedThresholds.filter { $0.key != streak.trackingKey },
            customStreaks: settings.customStreaks,
            gracePreservations: settings.gracePreservations
        )
        return candidates.first { $0.trackingKey == streak.trackingKey }?.threshold
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeatmapRangePicker(selectedRange: $selectedHeatmapRange)
                .padding(.bottom, 4)

            // Fixed height container so heatmap can fill it dynamically
            CalendarHeatmap(
                entries: heatmapEntries,
                accent: streak.metric.accent,
                selectedRange: $selectedHeatmapRange
            )
            .frame(height: 140)

            // Simplified binary legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(streak.metric.accent)
                        .frame(width: 10, height: 10)
                    Text("MET")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroInkDim)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Theme.retroInkFaint.opacity(0.5))
                        .frame(width: 10, height: 10)
                    Text("MISSED")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroInkDim)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Theme.retroInkFaint.opacity(0.2))
                        .frame(width: 10, height: 10)
                    Text("NO DATA")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroInkDim)
                }

                Spacer()

                Text("\(selectedHeatmapHits) HITS · \(String(format: "%.1f", avgHitsPerWeek)) / WK")
                    .font(RetroFont.pixel(8))
                    .foregroundStyle(Theme.retroInkDim)
            }
        }
        .padding(14)
        .pixelPanel(color: streak.metric.accent)
    }

    private var heatmapEntries: [HeatmapDay] {
        StreakEngine.dailyHistory(for: streak, history: store.history)
    }

    private var selectedHeatmapEntries: [HeatmapDay] {
        let today = DateHelpers.startOfDay()
        let start = DateHelpers.addDays(-(selectedHeatmapRange.days - 1), to: today)
        return heatmapEntries.filter { day in
            let date = DateHelpers.startOfDay(day.date)
            return date >= start && date <= today
        }
    }

    private var selectedHeatmapHits: Int {
        selectedHeatmapEntries.filter(\.met).count
    }

    private var avgHitsPerWeek: Double {
        let weeks = max(1.0, Double(selectedHeatmapRange.days) / 7.0)
        return Double(selectedHeatmapHits) / weeks
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCell(title: "CURRENT",
                     value: "\(streak.current)",
                     unit: "ACTIVE STREAK",
                     color: streak.metric.accent)
            statCell(title: "RECORD",
                     value: "\(streak.best)",
                     unit: "BEST STREAK",
                     color: Theme.retroAmber)
            statCell(title: "RATE",
                     value: "\(Int(streak.completionRate * 100))%",
                     unit: "COMPLETION",
                     color: Theme.retroMagenta)
        }
    }

    private func statCell(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(RetroFont.pixel(8))
                .tracking(1)
                .foregroundStyle(Theme.retroInkDim)
            Text(value)
                .font(RetroFont.pixel(20))
                .foregroundStyle(color)
                .retroGlow(color, radius: 8)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unit)
                .font(RetroFont.pixel(8))
                .foregroundStyle(Theme.retroInkDim)
                .lineLimit(1)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .pixelPanel(color: Theme.retroInkFaint)
    }

    // MARK: - Weekday histogram (hero only)

    private var weekdayHistogram: some View {
        let vals = weekdayValues()
        let median = vals.isEmpty ? 0 : vals.sorted()[vals.count / 2]
        let maxVal = max(1, vals.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("BY DAY OF WEEK")
                .font(RetroFont.pixel(9))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(vals[i] > median ? streak.metric.accent : Theme.retroInkFaint)
                            .frame(height: max(4, CGFloat(vals[i] / maxVal) * 60))
                        Text(["M","T","W","T","F","S","S"][i])
                            .font(RetroFont.pixel(8))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .pixelPanel(color: Theme.retroCyan)
    }

    private func weekdayValues() -> [Double] {
        var sums = [Double](repeating: 0, count: 7)
        var counts = [Double](repeating: 0, count: 7)
        let cal = DateHelpers.gregorian
        for d in store.history {
            let wd = cal.component(.weekday, from: d.date) // 1=Sun
            let idx = (wd + 5) % 7 // 0=Mon
            sums[idx] += d.value(for: streak.metric)
            counts[idx] += 1
        }
        return (0..<7).map { counts[$0] > 0 ? sums[$0] / counts[$0] : 0 }
    }

    // MARK: - Threshold ladder (hero only)

    private var thresholdLadder: some View {
        let thresholds = streak.metric.dailyThresholds

        return VStack(alignment: .leading, spacing: 0) {
            Text("THRESHOLD TIERS")
                .font(RetroFont.pixel(9))
                .tracking(2)
                .foregroundStyle(Theme.retroInkDim)
                .padding(.bottom, 10)

            ForEach(thresholds, id: \.self) { t in
                ladderRow(threshold: t)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroAmber)
    }

    private func ladderRow(threshold t: Double) -> some View {
        let s = StreakEngine.computeDailyStreak(
            metric: streak.metric,
            threshold: t,
            byDay: Dictionary(uniqueKeysWithValues: store.history.map { ($0.date, $0) }),
            today: DateHelpers.startOfDay()
        )
        let active = t == streak.threshold
        return HStack(spacing: 10) {
            Rectangle()
                .fill(streak.metric.accent)
                .frame(width: 4, height: 28)
                .opacity(active ? 1 : 0.2)
                .shadow(color: streak.metric.accent.opacity(active ? 0.8 : 0), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.metric.thresholdLabel(t, cadence: .daily).uppercased())
                    .font(RetroFont.pixel(10))
                    .foregroundStyle(active ? streak.metric.accent : Theme.retroInk)
                if active {
                    Text("◆ ACTIVE TIER")
                        .font(RetroFont.pixel(8))
                        .foregroundStyle(Theme.retroAmber)
                }
            }
            Spacer()
            Text("\(s.current) / best \(s.best)")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, active ? 8 : 0)
        .background(active ? streak.metric.accent.opacity(0.1) : .clear)
    }

    // MARK: - Date formatting helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
