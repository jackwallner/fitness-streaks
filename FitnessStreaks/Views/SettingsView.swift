import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var store: StreakStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases, id: \.rawValue) { a in
                            Text(a.label).tag(a)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("At-risk reminder", isOn: $settings.notificationsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Daily 7pm nudge if your hero streak isn't locked in yet.")
                }

                Section {
                    ForEach(StreakMetric.allCases) { metric in
                        Toggle(isOn: Binding(
                            get: { !settings.isHidden(metric) },
                            set: { on in
                                if on { settings.hiddenMetrics.remove(metric) }
                                else { settings.hiddenMetrics.insert(metric) }
                            }
                        )) {
                            HStack(spacing: 10) {
                                Image(systemName: metric.symbol)
                                    .foregroundStyle(metric.accent)
                                    .frame(width: 22)
                                Text(metric.displayName)
                            }
                        }
                    }
                } header: {
                    Text("Metrics tracked")
                } footer: {
                    Text("Turn off metrics you don't want to see streaks for.")
                }

                Section {
                    Button {
                        Task { await store.load() }
                        dismiss()
                    } label: {
                        Label("Refresh now", systemImage: "arrow.clockwise")
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("Privacy policy", destination: URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
