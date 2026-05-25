import SwiftUI
#if REVENUECAT
import RevenueCat
#endif

/// One-time free-trial offer presented shortly after a non-Pro user finishes
/// onboarding. Hybrid behavior:
/// - When a trial-bearing yearly package loaded, the primary CTA buys it directly
///   via StoreKit and the sheet shows the Apple 3.1.2-required price + auto-renew
///   disclosure plus a "See all plans" link to the full paywall.
/// - When no trial product loaded yet, the primary CTA falls through to the hosted
///   paywall instead.
struct TrialOfferSheet: View {
    /// Trial length copy, e.g. "7-day free trial". May be nil if products haven't loaded.
    let offerLabel: String?
    /// Recurring price after the trial. Required when `directPurchase` is true.
    let priceLabel: String?
    /// True when the primary button can buy the trial product directly via StoreKit.
    let directPurchase: Bool
    let isPurchasing: Bool
    let errorMessage: String?
    /// How many streaks the user picked at the end of onboarding *before* the free
    /// cap was enforced. When this exceeds `freeCap`, the sheet pivots its pitch
    /// to "keep all N you just earned" — the freshest, most in-the-moment Pro angle
    /// at first use. When it doesn't, the sheet falls back to a general "unlock
    /// everything" pitch.
    let pickedCount: Int
    let freeCap: Int
    /// Longest tracked streak the user currently has. Drives a personalized
    /// "Keep your N-day X streak alive" pitch when available — pulled from the
    /// live `StreakStore` at present time, not onboarding intent. Falls back to
    /// generic copy when nil (e.g., empty dashboard).
    let longestStreak: LongestStreakInfo?
    let onStartTrial: () -> Void
    let onSeeAllPlans: () -> Void
    let onDismiss: () -> Void

    struct LongestStreakInfo {
        let displayName: String
        let current: Int
        let cadenceLabel: String  // "day" / "week"
    }

    private static let privacyURL = URL(string: "https://jackwallner.github.io/fitness-streaks/privacy-policy.html")!
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// The user has at least one meaningful run going. Drive the entire pitch
    /// around the longest one — "keep your N-day X streak alive" beats generic
    /// "try Pro free" by a wide margin on first-impression conversion.
    private var hasMeaningfulStreak: Bool {
        (longestStreak?.current ?? 0) >= 3
    }

    /// Trial length parsed from `offerLabel` (e.g. "7-day free trial" → 7).
    /// Defaults to 7 when unparseable so the timeline still renders sensibly.
    private var trialDays: Int {
        guard let offerLabel,
              let first = offerLabel.split(separator: "-").first,
              let days = Int(first) else {
            return 7
        }
        return days
    }

    private var headline: String {
        if let s = longestStreak, hasMeaningfulStreak {
            return "KEEP YOUR \(s.current)-\(s.cadenceLabel.uppercased()) \(s.displayName.uppercased()) STREAK ALIVE."
        }
        if let offerLabel {
            return "\(offerLabel.uppercased()), ON US."
        }
        return "TRY STREAKS+ FREE."
    }

    private var subheadline: String {
        let trialClause = offerLabel.map { ", free for your \($0.replacingOccurrences(of: " free trial", with: ""))" } ?? ""
        if hasMeaningfulStreak {
            return "One missed \(longestStreak?.cadenceLabel ?? "day") zeroes it out. Streaks+ auto-saves the run and tracks every streak you've earned\(trialClause)."
        }
        if offerLabel != nil {
            return "Unlock the full Streaks+ toolkit free. No charge until your trial ends."
        }
        return "Unlock the full Streaks+ toolkit free for eligible new subscribers."
    }

    private var bullets: [TrialBullet] {
        let unlimitedDetail = "Free caps you at \(freeCap). Streaks+ tracks every metric you've earned, including future picks."
        return [
            TrialBullet(
                icon: "flame.fill",
                tint: Theme.retroMagenta,
                title: hasMeaningfulStreak
                    ? "Auto-save your \(longestStreak?.displayName ?? "streak") if you miss a day"
                    : "Auto-save when one breaks",
                detail: "Miss a \(longestStreak?.cadenceLabel ?? "day") later on? Streaks+ revives the run instead of zeroing it."
            ),
            TrialBullet(
                icon: "infinity",
                tint: Theme.retroCyan,
                title: "Track every streak",
                detail: unlimitedDetail
            ),
            TrialBullet(
                icon: "wand.and.stars",
                tint: Theme.retroLime,
                title: "Custom streaks",
                detail: "Define your own threshold, cadence, and hour window, beyond the discovered set."
            )
        ]
    }

    var body: some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    hero
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text(headline)
                            .font(.system(.title2, design: .monospaced, weight: .heavy))
                            .foregroundStyle(Theme.retroInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        Text(subheadline)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.retroInkDim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }

                    VStack(spacing: 10) {
                        ForEach(bullets) { TrialBulletRow(bullet: $0) }
                    }

                    if offerLabel != nil {
                        TrialTimeline(trialDays: trialDays, priceLabel: priceLabel)
                    }

                    if directPurchase, let priceLabel {
                        Text("Free during your trial, then \(priceLabel). Auto-renews unless cancelled at least 24 hours before the trial ends.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Theme.retroInkDim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Theme.retroRed)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    VStack(spacing: 10) {
                        Button(action: onStartTrial) {
                            ZStack {
                                Text("START MY FREE TRIAL")
                                    .font(.system(.headline, design: .monospaced, weight: .heavy))
                                    .foregroundStyle(Theme.retroBg)
                                    .opacity(isPurchasing ? 0 : 1)
                                if isPurchasing {
                                    ProgressView().tint(Theme.retroBg)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.retroLime, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Theme.retroInk, lineWidth: 2)
                            )
                            .shadow(color: Theme.retroInk, radius: 0, x: 3, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)

                        if offerLabel != nil {
                            Text("$0.00 DUE TODAY · CANCEL ANYTIME")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.retroLime)
                                .multilineTextAlignment(.center)
                        }

                        Text("Apple-managed subscription. Cancel anytime.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.retroInkFaint)
                            .multilineTextAlignment(.center)

                        if directPurchase {
                            Button(action: onSeeAllPlans) {
                                Text("See all plans")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.retroMagenta)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .disabled(isPurchasing)
                        }

                        Button(action: onDismiss) {
                            Text("Not now")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.retroInkDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)
                    }
                    .padding(.top, 4)

                    HStack(spacing: 6) {
                        Link("Terms", destination: Self.termsURL)
                        Text("·").foregroundStyle(Theme.retroInkFaint)
                        Link("Privacy Policy", destination: Self.privacyURL)
                    }
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.retroInkFaint)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.retroBgRaised)
                .frame(width: 88, height: 88)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.retroMagenta, lineWidth: 2)
                )
                .shadow(color: Theme.retroMagenta.opacity(0.6), radius: 0, x: 4, y: 4)
            Image(systemName: "flame.fill")
                .font(.system(size: 40, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.retroAmber, Theme.retroMagenta],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

private struct TrialBullet: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let detail: String
}

private struct TrialBulletRow: View {
    let bullet: TrialBullet

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bullet.tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(bullet.tint, lineWidth: 1.5)
                    )
                Image(systemName: bullet.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(bullet.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(bullet.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.retroInk)
                Text(bullet.detail)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.retroInkDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.retroBgRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.retroInkFaint, lineWidth: 1)
        )
    }
}
