import SwiftUI

/// Three-step "what happens during your trial" visual.
/// Day 0 → mid-trial reminder → first-charge date. Apple sends the reminder
/// 2 days before the charge; the labels in this component reflect that
/// schedule for a standard 7-day trial.
///
/// The explicit timeline beats a generic "Cancel anytime" line on trial-start
/// conversion — used by Cal AI, Headspace, Blinkist, Rise and most top
/// subscription apps because removing uncertainty about *when* money is
/// charged removes the largest reason to bail.
struct TrialTimeline: View {
    /// Trial length in days (7 for the standard intro offer).
    var trialDays: Int = 7
    /// Recurring price after the trial, e.g. "$29.99 / year". Optional —
    /// the final step still reads cleanly without it.
    var priceLabel: String?
    /// "$0.00" in the offer's currency.
    var zeroPriceLabel: String = Decimal(0).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))

    private var reminderDay: Int { max(1, trialDays - 2) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 0) {
                step(
                    index: 1,
                    accent: Theme.retroLime,
                    icon: "lock.open.fill",
                    title: String(localized: "TODAY"),
                    detail: String(localized: "Streaks+ unlocks instantly. \(zeroPriceLabel) charged.")
                )
                connector(Theme.retroInkFaint)
                step(
                    index: 2,
                    accent: Theme.retroCyan,
                    icon: "bell.fill",
                    title: String(localized: "DAY \(reminderDay)"),
                    detail: String(localized: "Apple emails you a heads-up before the trial ends.")
                )
                connector(Theme.retroInkFaint)
                step(
                    index: 3,
                    accent: Theme.retroMagenta,
                    icon: "creditcard.fill",
                    title: String(localized: "DAY \(trialDays)"),
                    detail: priceLabel.map { String(localized: "Trial ends · \($0) renews.") }
                        ?? String(localized: "Trial ends · subscription renews.")
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)
    }

    private func step(index: Int, accent: Color, icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().stroke(accent, lineWidth: 2))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
            }
            Text(title)
                .font(RetroFont.pixel(9))
                .tracking(1)
                .foregroundStyle(accent)
            Text(detail)
                .font(RetroFont.mono(9))
                .foregroundStyle(Theme.retroInkDim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func connector(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 12, height: 2)
            .padding(.top, 17)
    }
}
