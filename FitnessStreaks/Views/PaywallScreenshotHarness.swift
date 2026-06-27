#if DEBUG
import SwiftUI
#if REVENUECAT
import RevenueCat
#endif

struct PaywallScreenshotHarness: View {
    let mode: PaywallScreenshotMode
    @StateObject private var storeKit = StoreKitService.shared

    var body: some View {
        Group {
            if mode == .trial {
                trialBackdrop {
                    TrialOfferSheet(
                        offerLabel: trialPackage?.streaksIntroOfferLabel ?? "7-day free trial",
                        priceLabel: trialPackage?.streaksRecurringPriceLabel,
                        directPurchase: true,
                        isPurchasing: false,
                        errorMessage: nil,
                        pickedCount: 4,
                        freeCap: 2,
                        longestStreak: .init(displayName: "Morning run", current: 12, cadenceLabel: "day"),
                        onStartTrial: {},
                        onSeeAllPlans: {},
                        onDismiss: {}
                    )
                }
            } else {
                NavigationStack {
                    PaywallView(displayCloseButton: false)
                }
            }
        }
        .environmentObject(storeKit)
        .task {
            if storeKit.products.isEmpty { await storeKit.loadProducts() }
        }
    }

    #if REVENUECAT
    private var trialPackage: Package? {
        storeKit.yearly ?? storeKit.sortedPackages.first
    }
    #endif

    private func trialBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Theme.retroBg.ignoresSafeArea()
            Color.black.opacity(0.18).ignoresSafeArea()
            VStack {
                Spacer()
                content()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.68)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
    }
}
#endif
