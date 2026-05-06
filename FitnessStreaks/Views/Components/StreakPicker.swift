import SwiftUI

/// Reusable list of candidate streaks with toggles. Used in onboarding and Settings.
///
/// `selection` is a Set of "metric-cadence" keys. Binding so callers can persist as they wish.
struct StreakPickerList: View {
    let candidates: [Streak]
    @Binding var selection: Set<String>

    /// Highlight the top N as "recommended" — engine already sorted by vibe score.
    let recommendedCount: Int

    /// Called when user taps edit on a custom streak (passes the streak ID)
    var onEditCustom: ((String) -> Void)? = nil

    /// Core metrics that appear first in the list, ordered to mirror Apple's Activity rings.
    private let coreMetrics: [StreakMetric] = [.steps, .exerciseMinutes, .standHours, .activeEnergy, .workouts]

    private func coreOrder(_ metric: StreakMetric) -> Int {
        coreMetrics.firstIndex(of: metric) ?? Int.max
    }

    /// Sorted candidates with core metrics first
    private var sortedCandidates: [Streak] {
        candidates.sorted { a, b in
            let aIsCore = coreMetrics.contains(a.metric)
            let bIsCore = coreMetrics.contains(b.metric)
            if aIsCore != bIsCore {
                return aIsCore // Core metrics come first
            }
            if aIsCore && bIsCore {
                let ai = coreOrder(a.metric)
                let bi = coreOrder(b.metric)
                if ai != bi { return ai < bi }
            }
            // Within same category, maintain original order (by vibe score)
            guard let aIdx = candidates.firstIndex(where: { $0.id == a.id }),
                  let bIdx = candidates.firstIndex(where: { $0.id == b.id }) else {
                return false
            }
            return aIdx < bIdx
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(sortedCandidates.enumerated()), id: \.element.id) { idx, streak in
                let isCore = coreMetrics.contains(streak.metric)
                row(streak, recommended: isCore) // Core metrics get star
            }
        }
    }

    private func row(_ streak: Streak, recommended: Bool) -> some View {
        let key = streak.trackingKey
        let on = selection.contains(key)
        let accent = streak.metric.accent
        let isCustom = streak.customID != nil

        return HStack(spacing: 0) {
            Button {
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
                            Text(streak.displayName.uppercased())
                                .font(RetroFont.mono(11, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.retroInk)
                            if isCustom {
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

            if isCustom, let onEdit = onEditCustom, let customID = streak.customID {
                Button {
                    onEdit(customID)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.retroCyan)
                        .frame(width: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func subtitle(for streak: Streak) -> String {
        let label = streak.thresholdLabel
        if let window = streak.window {
            return "\(streak.current) \(streak.cadence.pluralLabel) in a row · \(label) between \(window.label)"
        }
        return "\(streak.current) \(streak.cadence.pluralLabel) in a row · \(label) daily"
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
    @EnvironmentObject var storeKit: StoreKitService
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<String> = []
    @State private var showingBuilder = false
    @State private var editingCustomID: String? = nil
    @State private var showingPaywall = false

    /// Free tier gets one custom streak; Pro unlocks unlimited.
    static let freeCustomLimit = 1

    private var canBuildCustom: Bool {
        storeKit.isPro || settings.customStreaks.count < Self.freeCustomLimit
    }

    private var editingCustomStreak: CustomStreak? {
        editingCustomID.flatMap { id in settings.customStreaks.first(where: { $0.id == id }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pick the streaks you want on your dashboard.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)

                    Text("ALL STREAKS")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    StreakPickerList(
                        candidates: store.allCandidates,
                        selection: $selection,
                        recommendedCount: min(5, store.allCandidates.count),
                        onEditCustom: { id in editingCustomID = id }
                    )
                    .padding(.horizontal, 14)

                    Button {
                        if canBuildCustom {
                            showingBuilder = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        HStack {
                            Text(canBuildCustom ? "+ BUILD YOUR OWN" : "+ BUILD YOUR OWN — PRO")
                                .font(RetroFont.mono(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(canBuildCustom ? Theme.retroLime : Theme.retroMagenta)
                            Spacer()
                            Text(canBuildCustom ? "CUSTOM" : "LOCKED")
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(canBuildCustom ? Theme.retroInkDim : Theme.retroMagenta)
                        }
                        .padding(14)
                        .pixelPanel(color: canBuildCustom ? Theme.retroLime : Theme.retroMagenta, fill: Theme.retroBgRaised)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)

                    if !canBuildCustom {
                        Text("Free includes 1 custom streak. Unlock Pro for unlimited.")
                            .font(RetroFont.mono(10))
                            .foregroundStyle(Theme.retroInkDim)
                            .padding(.horizontal, 14)
                    }

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
                            .foregroundStyle(selection.isEmpty ? Theme.retroInkFaint : Theme.retroLime)
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingBuilder) {
                CustomStreakBuilderSheet { custom in
                    settings.customStreaks.append(custom)
                    selection.insert(custom.trackingKey)
                    Task { await store.load() }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(context: "Pro unlocks unlimited custom streaks. Free includes one — yours is already saved.")
                    .environmentObject(storeKit)
                    .environmentObject(settings)
            }
            .sheet(isPresented: Binding(
                get: { editingCustomID != nil },
                set: { if !$0 { editingCustomID = nil } }
            )) {
                if let id = editingCustomID, let custom = settings.customStreaks.first(where: { $0.id == id }) {
                    CustomStreakEditSheet(custom: custom) { newThreshold in
                        settings.updateCustomStreak(id: id, threshold: newThreshold)
                        editingCustomID = nil
                        Task { await store.load() }
                    }
                }
            }
        }
        .onAppear {
            if let current = settings.trackedStreaks {
                selection = current
            } else {
                selection = []
            }
        }
    }

    private func save() {
        settings.trackedStreaks = selection
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
    @State private var usesWorkoutType = false
    @State private var workoutTypeKey: String = WorkoutTypeCatalog.all.first?.key ?? "running"
    @State private var workoutMeasure: WorkoutMeasure = .minutes

    private var workoutEntry: WorkoutTypeCatalog.Entry? {
        WorkoutTypeCatalog.entry(forKey: workoutTypeKey)
    }

    private var allowsFractionalThreshold: Bool {
        if metric == .workouts && usesWorkoutType {
            return workoutMeasure == .miles
        }
        switch metric {
        case .sleepHours, .distanceMiles, .intensityRatio:
            return true
        default:
            return false
        }
    }

    private var sanitizedThreshold: Double {
        if metric == .workouts && !usesWorkoutType { return 1 }
        return threshold
    }

    private var thresholdIsValid: Bool {
        sanitizedThreshold.isFinite
            && sanitizedThreshold > 0
            && (allowsFractionalThreshold || sanitizedThreshold.rounded() == sanitizedThreshold)
    }

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
                        .onChange(of: metric) { _, newMetric in
                            if newMetric == .workouts {
                                threshold = 1
                                usesHourWindow = false
                                if usesWorkoutType {
                                    threshold = defaultThreshold(for: workoutMeasure)
                                }
                            } else {
                                usesWorkoutType = false
                            }
                        }

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
                                .keyboardType(allowsFractionalThreshold ? .decimalPad : .numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(RetroFont.mono(12, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                                .frame(width: 120)
                                .disabled(metric == .workouts)
                            Text(metric.unitLabel.uppercased())
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        .padding(14)

                        if !thresholdIsValid {
                            Text(allowsFractionalThreshold ? "Enter a value greater than 0." : "Enter a whole number greater than 0.")
                                .font(RetroFont.mono(10))
                                .foregroundStyle(Theme.retroRed)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }

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

                        if metric == .workouts {
                            Rectangle()
                                .fill(Theme.retroInkFaint)
                                .frame(height: 1)
                                .padding(.horizontal, 14)

                            HStack {
                                Text("PICK ACTIVITY TYPE")
                                    .font(RetroFont.mono(10, weight: .bold))
                                    .foregroundStyle(Theme.retroInk)
                                Spacer()
                                PixelToggle(isOn: Binding(
                                    get: { usesWorkoutType },
                                    set: { newValue in
                                        usesWorkoutType = newValue
                                        if newValue {
                                            threshold = defaultThreshold(for: workoutMeasure)
                                        } else {
                                            threshold = 1
                                        }
                                    }
                                ), accent: Theme.retroAmber)
                            }
                            .padding(14)

                            if usesWorkoutType {
                                Picker("Activity", selection: $workoutTypeKey) {
                                    ForEach(WorkoutTypeCatalog.all) { entry in
                                        Text(entry.displayName).tag(entry.key)
                                    }
                                }
                                .pickerStyle(.navigationLink)
                                .padding(14)
                                .onChange(of: workoutTypeKey) { _, _ in
                                    if let entry = workoutEntry, !entry.supportsDistance, workoutMeasure == .miles {
                                        workoutMeasure = .minutes
                                        threshold = defaultThreshold(for: .minutes)
                                    }
                                }

                                HStack {
                                    Text("MEASURE")
                                        .font(RetroFont.mono(10, weight: .bold))
                                        .foregroundStyle(Theme.retroInk)
                                    Spacer()
                                    Picker("", selection: $workoutMeasure) {
                                        ForEach(availableMeasures(), id: \.self) { measure in
                                            Text(measure.label).tag(measure)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                    .onChange(of: workoutMeasure) { _, newValue in
                                        threshold = defaultThreshold(for: newValue)
                                    }
                                }
                                .padding(14)
                            }
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
                        let attachWorkoutType = metric == .workouts && usesWorkoutType
                        onSave(CustomStreak(
                            id: UUID().uuidString,
                            metric: metric,
                            cadence: .daily,
                            threshold: sanitizedThreshold,
                            hourWindow: usesHourWindow && metric == .steps ? hour : nil,
                            workoutType: attachWorkoutType ? workoutTypeKey : nil,
                            workoutMeasure: attachWorkoutType ? workoutMeasure : nil
                        ))
                        dismiss()
                    } label: {
                        Text("ADD")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(thresholdIsValid ? Theme.retroLime : Theme.retroInkFaint)
                    }
                    .disabled(!thresholdIsValid)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func availableMeasures() -> [WorkoutMeasure] {
        guard let entry = workoutEntry else { return [.count, .minutes] }
        return entry.supportsDistance ? WorkoutMeasure.allCases : [.count, .minutes]
    }

    private func defaultThreshold(for measure: WorkoutMeasure) -> Double {
        switch measure {
        case .count: return 1
        case .minutes: return 20
        case .miles: return 1
        }
    }
}

/// Sheet for editing a custom streak's threshold.
struct CustomStreakEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let custom: CustomStreak
    let onSave: (Double) -> Void

    @State private var threshold: Double = 0

    private var metric: StreakMetric { custom.metric }

    private var allowsFractional: Bool {
        if metric == .workouts && custom.workoutType != nil {
            return custom.workoutMeasure == .miles
        }
        switch metric {
        case .sleepHours, .distanceMiles, .intensityRatio:
            return true
        default:
            return false
        }
    }

    private var step: Double {
        switch metric {
        case .steps, .earlySteps: return 100
        case .activeEnergy: return 10
        case .distanceMiles, .intensityRatio, .sleepHours: return 0.1
        default: return 1
        }
    }

    private var minValue: Double {
        switch metric {
        case .steps, .earlySteps: return 100
        case .activeEnergy: return 10
        case .distanceMiles, .intensityRatio, .sleepHours: return 0.1
        default: return 1
        }
    }

    private var maxValue: Double {
        switch metric {
        case .steps: return 50000
        case .earlySteps: return 10000
        case .activeEnergy: return 2000
        case .distanceMiles: return 26.0
        case .sleepHours: return 12.0
        case .intensityRatio: return 2.0
        case .exerciseMinutes, .mindfulMinutes, .heartRateMinutes: return 60
        case .standHours: return 12
        case .flightsClimbed: return 50
        case .workouts:
            if custom.workoutType != nil {
                switch custom.workoutMeasure {
                case .miles: return 26.0
                case .minutes: return 180
                default: return 10
                }
            }
            return 10
        default: return 180
        }
    }

    private var thresholdIsValid: Bool {
        threshold.isFinite && threshold > 0 && threshold <= maxValue &&
        (allowsFractional || threshold.rounded() == threshold)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Adjust the goal threshold for this streak.")
                        .font(RetroFont.mono(11))
                        .foregroundStyle(Theme.retroInkDim)
                        .padding(.horizontal, 14)

                    VStack(spacing: 16) {
                        HStack {
                            Text("METRIC")
                                .font(RetroFont.mono(10, weight: .bold))
                                .foregroundStyle(Theme.retroInkDim)
                            Spacer()
                            Text(metric.displayName.uppercased())
                                .font(RetroFont.mono(11, weight: .bold))
                                .foregroundStyle(Theme.retroInk)
                        }
                        .padding(.horizontal, 14)

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
                                .keyboardType(allowsFractional ? .decimalPad : .numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(RetroFont.mono(12, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                                .frame(width: 120)
                            Text(metric.unitLabel.uppercased())
                                .font(RetroFont.mono(9, weight: .bold))
                                .foregroundStyle(Theme.retroInkDim)
                        }
                        .padding(.horizontal, 14)

                        if !thresholdIsValid {
                            Text(allowsFractional ? "Enter a value between \(format(minValue)) and \(format(maxValue))." : "Enter a whole number between \(Int(minValue)) and \(Int(maxValue)).")
                                .font(RetroFont.mono(10))
                                .foregroundStyle(Theme.retroRed)
                                .padding(.horizontal, 14)
                        }

                        Stepper("", value: $threshold, step: step)
                            .labelsHidden()
                            .padding(.horizontal, 14)
                            .disabled(threshold + step > maxValue && threshold - step < minValue)
                    }
                    .padding(.vertical, 16)
                    .pixelPanel(color: Theme.retroInkFaint)
                    .padding(.horizontal, 14)

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EDIT THRESHOLD")
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
                        onSave(threshold)
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(thresholdIsValid ? Theme.retroLime : Theme.retroInkFaint)
                    }
                    .disabled(!thresholdIsValid)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                threshold = custom.threshold
            }
        }
    }

    private func format(_ value: Double) -> String {
        if allowsFractional {
            return value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
        }
        return String(Int(value))
    }
}
