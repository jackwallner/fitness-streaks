import SwiftUI

struct BrokenStreakSheet: View {
    let broken: BrokenStreak
    let restart: () -> Void
    let pickNew: () -> Void
    let dismiss: () -> Void

    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var settings: StreakSettings

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
                        Text("Your \(broken.metric.displayName.lowercased()) run ended at \(broken.brokenLength) \(broken.cadence.pluralLabel). Keep the same goal on your dashboard or pick a new one.")
                            .font(RetroFont.mono(12))
                            .foregroundStyle(Theme.retroInk)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .pixelPanel(color: Theme.retroRed, fill: Theme.retroBgRaised)

                    if shouldShowUpsell {
                        graceUpsell
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
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(context: paywallContext)
                    .environmentObject(storeKit)
                    .environmentObject(settings)
            }
        }
    }

    private var shouldShowUpsell: Bool {
        !storeKit.isPro && settings.earnedGraceDays > 0
    }

    private var paywallContext: String {
        let n = settings.earnedGraceDays
        return "Save your \(broken.brokenLength)-\(broken.cadence.label) \(broken.metric.displayName.lowercased()) streak. You have \(n) Grace Day\(n == 1 ? "" : "s") banked — unlock Pro to spend one and restore it."
    }

    private var graceUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.retroLime)
                    Text("YOU HAVE \(settings.earnedGraceDays) GRACE DAY\(settings.earnedGraceDays == 1 ? "" : "S") BANKED")
                        .font(RetroFont.pixel(10))
                        .tracking(1)
                        .foregroundStyle(Theme.retroLime)
                    Spacer()
                    PixelChip(text: "PRO", accent: Theme.retroMagenta)
                }
                Text("Unlock FitnessStreaks Pro to spend one and save this streak. Future misses will be saved automatically.")
                    .font(RetroFont.mono(11))
                    .foregroundStyle(Theme.retroInk)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                HStack {
                    Text("UNLOCK PRO")
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
        .accessibilityLabel("Unlock Pro to use a banked Grace Day and save this streak")
    }
}
