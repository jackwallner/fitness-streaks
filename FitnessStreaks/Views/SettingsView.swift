import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var store: StreakStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    notificationsSection
                    metricsSection
                    dataSection
                    aboutSection

                    Text("READ-ONLY · LOCAL-ONLY · NO NETWORK")
                        .font(RetroFont.pixel(8))
                        .tracking(2)
                        .foregroundStyle(Theme.retroInkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(RetroFont.pixel(12))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text("DONE")
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroCyan)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Appearance")
            HStack(spacing: 0) {
                ForEach(AppAppearance.allCases, id: \.rawValue) { a in
                    Button {
                        settings.appearance = a
                    } label: {
                        Text(a.label.uppercased())
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(settings.appearance == a ? Theme.retroBg : Theme.retroInk)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(settings.appearance == a ? Theme.retroCyan : Color.clear)
                            .overlay(Rectangle().stroke(settings.appearance == a ? Theme.retroCyan : Theme.retroInkFaint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Notifications")
            HStack {
                Text("AT-RISK REMINDER")
                    .font(RetroFont.pixel(10))
                    .foregroundStyle(Theme.retroInk)
                Spacer()
                PixelToggle(isOn: $settings.notificationsEnabled, accent: Theme.retroMagenta)
            }
            .padding(14)
            .pixelPanel(color: Theme.retroInkFaint)

            Text("Daily 7pm nudge if your hero streak isn't locked in yet.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
                .padding(.horizontal, 6)
        }
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Metrics Tracked")
            VStack(spacing: 0) {
                ForEach(Array(StreakMetric.allCases.enumerated()), id: \.offset) { idx, metric in
                    HStack(spacing: 10) {
                        Image(systemName: metric.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(metric.accent)
                            .shadow(color: metric.accent.opacity(0.6), radius: 4)
                            .frame(width: 24)
                        Text(metric.displayName.uppercased())
                            .font(RetroFont.pixel(10))
                            .foregroundStyle(Theme.retroInk)
                        Spacer()
                        PixelToggle(isOn: Binding(
                            get: { !settings.isHidden(metric) },
                            set: { on in
                                if on { settings.hiddenMetrics.remove(metric) }
                                else { settings.hiddenMetrics.insert(metric) }
                            }
                        ), accent: metric.accent)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    if idx < StreakMetric.allCases.count - 1 {
                        dashedLine
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    private var dashedLine: some View {
        Rectangle()
            .fill(Theme.retroInkFaint)
            .frame(height: 1)
            .opacity(0.6)
            .padding(.horizontal, 14)
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "Data")
            Button {
                Task { await store.load() }
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("REFRESH NOW")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                }
                .foregroundStyle(Theme.retroLime)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionHeader(title: "About")
            VStack(spacing: 0) {
                aboutRow(label: "VERSION",
                         value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                dashedLine
                if let url = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html") {
                    Link(destination: url) {
                        HStack {
                            Text("PRIVACY POLICY")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.pixel(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                }
                dashedLine
                if let url = URL(string: "https://github.com/jackwallner/fitness-streaks") {
                    Link(destination: url) {
                        HStack {
                            Text("SOURCE")
                                .font(RetroFont.pixel(10))
                                .foregroundStyle(Theme.retroInk)
                            Spacer()
                            Text("↗")
                                .font(RetroFont.pixel(11))
                                .foregroundStyle(Theme.retroCyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                    }
                }
            }
            .pixelPanel(color: Theme.retroInkFaint)
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(RetroFont.pixel(10))
                .foregroundStyle(Theme.retroInk)
            Spacer()
            Text(value)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
    }
}
