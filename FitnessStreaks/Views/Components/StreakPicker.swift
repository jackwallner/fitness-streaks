import SwiftUI

/// Reusable list of candidate streaks with toggles. Used in onboarding and Settings.
///
/// `selection` is a Set of "metric-cadence" keys. Binding so callers can persist as they wish.
struct StreakPickerList: View {
    let candidates: [Streak]
    @Binding var selection: Set<String>

    /// Highlight the top N as "recommended" — engine already sorted by vibe score.
    let recommendedCount: Int

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { idx, streak in
                row(streak, recommended: idx < recommendedCount)
            }
        }
    }

    private func row(_ streak: Streak, recommended: Bool) -> some View {
        let key = streak.trackingKey
        let on = selection.contains(key)
        let accent = streak.metric.accent
        return Button {
            if on { selection.remove(key) } else { selection.insert(key) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: streak.metric.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.6), radius: 4)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(streak.metric.displayName.uppercased())
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInk)
                        if streak.customID != nil {
                            Text("CUSTOM")
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                        }
                        Text(cadenceLabel(for: streak))
                            .font(RetroFont.mono(9, weight: .bold))
                            .foregroundStyle(streak.window != nil ? Theme.retroAmber : Theme.retroInkDim)
                        if recommended {
                            Text("★")
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroAmber)
                        }
                    }
                    Text(subtitle(for: streak))
                        .font(RetroFont.mono(10))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                Text(on ? "◉" : "○")
                    .font(RetroFont.mono(18, weight: .bold))
                    .foregroundStyle(on ? accent : Theme.retroInkFaint)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: on ? accent : Theme.retroInkFaint,
                        fill: on ? Theme.retroBgCard : Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for streak: Streak) -> String {
        let label = streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence)
        if let window = streak.window {
            return "\(streak.current) \(streak.cadence.pluralLabel) · \(label) between \(window.label)"
        }
        return "\(streak.current) \(streak.cadence.pluralLabel) · \(label) daily"
    }

    private func cadenceLabel(for streak: Streak) -> String {
        if let w = streak.window {
            return "BY \(w.label.uppercased())"
        }
        return "DAILY"
    }
}

/// Full-screen picker presented from Settings. Onboarding embeds StreakPickerList directly.
struct StreakPickerSheet: View {
    @EnvironmentObject var store: StreakStore
    @EnvironmentObject var settings: StreakSettings
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<String> = []
    @State private var orderedSelection: [String] = []
    @State private var showingBuilder = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pick the streaks you want on your dashboard. ★ are the most interesting for your current vibe.\n\nDrag to reorder — first becomes your primary streak.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)

                    // Reorder section: only selected streaks, draggable
                    if !selectedStreaks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR ORDER (drag to reorder)")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroMagenta)
                                .padding(.horizontal, 14)

                            LazyVStack(spacing: 8) {
                                ForEach(selectedStreaks) { streak in
                                    reorderRow(streak)
                                }
                                .onMove(perform: move)
                            }
                            .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 8)
                        .background(Theme.retroBgRaised)
                    }

                    Text("ALL STREAKS")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    StreakPickerList(
                        candidates: store.allCandidates,
                        selection: $selection,
                        recommendedCount: min(5, store.allCandidates.count)
                    )
                    .padding(.horizontal, 14)

                    Button {
                        showingBuilder = true
                    } label: {
                        HStack {
                            Text("+ BUILD YOUR OWN")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroLime)
                            Spacer()
                            Text("CUSTOM")
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        .padding(14)
                        .pixelPanel(color: Theme.retroLime, fill: Theme.retroBgRaised)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)

                    if store.allCandidates.isEmpty {
                        Text("No streaks discovered yet — pull to refresh once Apple Health has some activity.")
                            .font(RetroFont.mono(11))
                            .foregroundStyle(Theme.retroInkDim)
                            .padding(.horizontal, 14)
                            .padding(.top, 40)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TRACKED STREAKS")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        Text("SAVE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroLime)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingBuilder) {
                CustomStreakBuilderSheet { custom in
                    settings.customStreaks.append(custom)
                    selection.insert(custom.trackingKey)
                    orderedSelection.append(custom.trackingKey)
                    Task { await store.load() }
                }
            }
        }
        .onAppear {
            if let current = settings.trackedStreaks {
                selection = current
                orderedSelection = settings.manualStreakOrder.filter { current.contains($0) }
            } else {
                // First time — preselect the recommended top 5
                let preselected = store.allCandidates.prefix(5).map { $0.trackingKey }
                selection = Set(preselected)
                orderedSelection = preselected
            }
        }
        .onChange(of: selection) { _, new in
            // Add newly selected items to the end of orderedSelection
            for key in new where !orderedSelection.contains(key) {
                orderedSelection.append(key)
            }
            // Remove deselected items from orderedSelection
            orderedSelection.removeAll { !new.contains($0) }
        }
    }

    private var selectedStreaks: [Streak] {
        orderedSelection.compactMap { key in
            store.allCandidates.first { $0.trackingKey == key }
        }
    }

    private func reorderRow(_ streak: Streak) -> some View {
        let accent = streak.metric.accent
        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundStyle(Theme.retroInkFaint)
            Image(systemName: streak.metric.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.metric.displayName.uppercased())
                    .font(RetroFont.mono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.retroInk)
                Text(streak.metric.thresholdLabel(streak.threshold, cadence: streak.cadence))
                    .font(RetroFont.mono(9))
                    .foregroundStyle(Theme.retroInkDim)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.retroBg)
        .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 1))
    }

    private func move(from source: IndexSet, to destination: Int) {
        orderedSelection.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        settings.trackedStreaks = selection
        settings.manualStreakOrder = orderedSelection
        store.refilter()
        dismiss()
    }
}

struct CustomStreakBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (CustomStreak) -> Void

    @State private var metric: StreakMetric = .steps
    @State private var threshold: Double = 3_000
    @State private var usesHourWindow = false
    @State private var hour = 10

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create a fixed goal that stays locked until you edit it.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.horizontal, 14)

                    VStack(spacing: 0) {
                        Picker("Metric", selection: $metric) {
                            ForEach(StreakMetric.allCases) { metric in
                                Text(metric.displayName).tag(metric)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .padding(14)

                        Rectangle()
                            .fill(Theme.retroInkFaint)
                            .frame(height: 1)
                            .padding(.horizontal, 14)

                        HStack {
                            Text("THRESHOLD")
                                .font(RetroFont.mono(10, weight: .bold))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            TextField("0", value: $threshold, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(RetroFont.mono(12, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                                .frame(width: 120)
                            Text(metric.unitLabel.uppercased())
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        .padding(14)

                        Rectangle()
                            .fill(Theme.retroInkFaint)
                            .frame(height: 1)
                            .padding(.horizontal, 14)

                        if metric == .steps {
                            HStack {
                                Text("TIME WINDOW")
                                    .font(RetroFont.mono(10, weight: .bold))
                                    .foregroundStyle(Theme.retroInk)
                                Spacer()
                                PixelToggle(isOn: $usesHourWindow, accent: Theme.retroAmber)
                            }
                            .padding(14)
                        }

                        if usesHourWindow && metric == .steps {
                            Picker("Hour", selection: $hour) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(HourWindow(startHour: h).label).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                    }
                    .pixelPanel(color: Theme.retroInkFaint)
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CUSTOM STREAK")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Text("CANCEL")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSave(CustomStreak(
                            id: UUID().uuidString,
                            metric: metric,
                            cadence: .daily,
                            threshold: threshold,
                            hourWindow: usesHourWindow && metric == .steps ? hour : nil
                        ))
                        dismiss()
                    } label: {
                        Text("ADD")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroLime)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
