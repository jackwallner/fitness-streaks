import SwiftUI
#if REVENUECAT
import RevenueCat
#endif

/// One-time free-trial offer presented shortly after a non-Pro user finishes
/// onboarding. Hybrid behavior:
/// - When a trial-bearing yearly package loaded, the primary CTA buys it directly
///   via StoreKit and the sheet shows the Apple 3.1.2-required price + auto-renew
///   disclosure plus a "See all plans" link to the full paywall.
/// - When no trial product loaded yet, the primary CTA opens the full native paywall.
struct TrialOfferSheet: View {
    @EnvironmentObject private var storeKit: StoreKitService
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
    /// Optional copy overrides for contexts where the default "keep alive" framing
    /// is wrong (e.g. the broken-streak revival, where the run has *already* ended).
    /// Default nil preserves the onboarding pitch verbatim.
    var headlineOverride: String? = nil
    var subheadlineOverride: String? = nil
    let onStartTrial: () -> Void
    let onSeeAllPlans: () -> Void
    let onDismiss: () -> Void

    @State private var restoreStatus: String?

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
        if let headlineOverride { return headlineOverride }
        if let s = longestStreak, hasMeaningfulStreak {
            return "KEEP YOUR \(s.current)-\(s.cadenceLabel.uppercased()) \(s.displayName.uppercased()) STREAK ALIVE."
        }
        if let offerLabel {
            return "\(offerLabel.uppercased()), ON US."
        }
        return "TRY STREAKS+ FREE."
    }

    private var subheadline: String {
        if let subheadlineOverride { return subheadlineOverride }
        // "7-day free trial" -> ", free for your 7-day trial" (keeping "trial" so the
        // sentence doesn't dangle as "...earned, free for your 7-day.").
        let trialClause = offerLabel.map { ", free for your \($0.replacingOccurrences(of: " free trial", with: " trial"))" } ?? ""
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
                VStack(spacing: 16) {
                    hero
                        .padding(.top, 18)

                    VStack(spacing: 8) {
                        Text(headline)
                            .font(.system(.title3, design: .monospaced, weight: .heavy))
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
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyActionBlock
        }
    }

    /// Pinned action stack: CTA + disclosure + secondary links. Always visible so
    /// the user never has to scroll to find "Start my free trial".
    private var stickyActionBlock: some View {
        VStack(spacing: 8) {
            if directPurchase, let priceLabel, let offerLabel {
                let footnote: String = {
                    #if REVENUECAT
                    if let package = trialPackage {
                        return PaywallDisclosure.subscriptionFootnote(
                            package: package,
                            displayPrice: priceLabel,
                            isEligibleForIntro: true
                        )
                    }
                    #endif
                    return "\(offerLabel.capitalized), then \(priceLabel). Renews automatically unless you cancel at least 24 hours before the trial ends."
                }()
                Text(footnote)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.retroRed)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Button(action: onStartTrial) {
                ZStack {
                    VStack(spacing: 2) {
                        Text(primaryCTATitle)
                            .font(.system(.headline, design: .monospaced, weight: .heavy))
                            .foregroundStyle(Theme.retroBg)
                        // Apple 3.1.2(c): the billed amount must be the most
                        // conspicuous price on the sheet — footnote size keeps it
                        // above every other pricing element ($0.00 line, legal copy).
                        if let subtitle = primaryCTASubtitle {
                            Text(subtitle)
                                .font(.system(.footnote, design: .monospaced, weight: .heavy))
                                .foregroundStyle(Theme.retroBg)
                                .tracking(0.5)
                        }
                    }
                    .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(Theme.retroBg)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // Hard retro shadow lives on the background shape only. Applying
                // .shadow to the whole composite double-prints the label text as a
                // dark offset ghost on the lime fill.
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.retroLime)
                        .shadow(color: Theme.retroInk, radius: 0, x: 3, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Theme.retroInk, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            // Subordinate to the billed amount in the CTA (Apple 3.1.2(c)):
            // dim ink, caption size — reassurance, not the headline price.
            if offerLabel != nil {
                Text("$0.00 due today · Billed by Apple")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.retroInkDim)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 18) {
                if directPurchase {
                    Button(action: onSeeAllPlans) {
                        Text("See all plans")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.retroMagenta)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                }
                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.retroInkDim)
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }

            HStack(spacing: 6) {
                Link("Terms", destination: Self.termsURL)
                Text("·").foregroundStyle(Theme.retroInkFaint)
                Link("Privacy", destination: Self.privacyURL)
                Text("·").foregroundStyle(Theme.retroInkFaint)
                Button("Restore") {
                    Task { await restorePurchases() }
                }
                .foregroundStyle(Theme.retroMagenta)
            }
            .font(.system(.caption2, design: .rounded))

            if let restoreStatus {
                Text(restoreStatus)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.retroAmber)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            Theme.retroBg
                .overlay(Rectangle().fill(Theme.retroInkFaint).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    #if REVENUECAT
    private var trialPackage: Package? {
        let trials = storeKit.products.filter { $0.streaksIntroOfferLabel != nil }
        return trials.first(where: { $0.packageType == .annual }) ?? trials.first
    }
    #endif

    /// CTA names the plan + recurring price (Apple 3.1.2). "Start my free trial"
    /// alone has been rejected for not disclosing the subscription term.
    private var primaryCTATitle: String {
        if !directPurchase { return "SEE PLANS" }
        if offerLabel != nil { return "START FREE TRIAL" }
        return "SUBSCRIBE"
    }

    private var primaryCTASubtitle: String? {
        guard directPurchase, let priceLabel else { return nil }
        if offerLabel != nil {
            return "THEN \(priceLabel.uppercased())"
        }
        return priceLabel.uppercased()
    }

    private func restorePurchases() async {
        restoreStatus = "Restoring…"
        await storeKit.restore()
        if storeKit.isPro {
            restoreStatus = "Streaks+ restored."
        } else {
            restoreStatus = storeKit.lastError ?? "No active subscription found."
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
