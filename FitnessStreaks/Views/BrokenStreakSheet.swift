import SwiftUI

struct BrokenStreakSheet: View {
    let broken: BrokenStreak
    let restart: () -> Void
    let pickNew: () -> Void
    let dismiss: () -> Void

    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    @Environment(\.dismiss) private var close
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PixelFlame(size: 64, intensity: 0.5, tint: Theme.retroRed)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("STREAK ENDED")
                            .font(RetroFont.mono(12, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Theme.retroRed)
                        Text("Your \(broken.metric.displayName.lowercased()) run ended at \(broken.brokenLength) \(broken.cadence.pluralLabel).")
                            .font(RetroFont.mono(12))
                            .foregroundStyle(Theme.retroInk)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .pixelPanel(color: Theme.retroRed, fill: Theme.retroBgRaised)

                    if shouldShowUpsell {
                        revivalUpsell
                    }

                    Button {
                        restart()
                        close()
                    } label: {
                        Text("KEEP SAME GOAL")
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroBg)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Theme.retroLime)
                    }
                    .buttonStyle(.plain)

                    Button {
                        pickNew()
                        close()
                    } label: {
                        Text("PICK A NEW GOAL")
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroCyan)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RECOVERY")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        close()
                    } label: {
                        Text("CLOSE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingPaywall, onDismiss: handlePaywallDismiss) {
                PaywallView(paywallImpressionId: "streaks_broken_sheet")
            }
        }
    }

    private var shouldShowUpsell: Bool {
        !storeKit.isPro && canRevive
    }

    /// We can only bridge a single missed day. If the break is older than
    /// yesterday, an upgrade still gets them Pro but can't retroactively revive
    /// this particular run, so we fall back to the standard recovery options.
    private var canRevive: Bool {
        let missed = DateHelpers.startOfDay(broken.brokenAt)
        let today = DateHelpers.startOfDay(.now)
        let days = DateHelpers.gregorian.dateComponents([.day], from: missed, to: today).day ?? 0
        return days <= 1
    }

    private func handlePaywallDismiss() {
        guard storeKit.isPro else { return }
        Task {
            await store.reviveBrokenStreak(broken)
            close()
        }
    }

    private var revivalUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.retroLime)
                    Text("REVIVE WITH A PRO TRIAL")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                        .foregroundStyle(Theme.retroLime)
                    Spacer()
                    PixelChip(text: "PRO", accent: Theme.retroMagenta)
                }
                Text("Start a Pro trial and we'll restore your \(broken.brokenLength)-\(broken.cadence.label) \(broken.metric.displayName.lowercased()) run on the spot. Pro auto-saves every missed day so this doesn't happen again.")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInk)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text("START TRIAL · REVIVE STREAK")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroMagenta)
                    Spacer()
                    Text("›")
                        .font(RetroFont.mono(14, weight: .bold))
                        .foregroundStyle(Theme.retroMagenta)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel(color: Theme.retroLime, fill: Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a Pro trial to revive your \(broken.brokenLength)-\(broken.cadence.label) \(broken.metric.displayName.lowercased()) streak")
    }
}
