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
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: present like the app does, as a real sheet.
                Theme.retroBg.ignoresSafeArea()
                    .sheet(isPresented: .constant(true)) {
                        if mode == .trial { trialSheet.presentationDetents([.large]) }
                        else { PaywallView() }
                    }
            } else if mode == .trial {
                trialBackdrop { trialSheet }
            } else {
                NavigationStack {
                    PaywallView(displayCloseButton: false)
                }
            }
        }
        .environmentObject(storeKit)
        .forceLandscapeIfRequested()
        .task {
            if storeKit.products.isEmpty { await storeKit.loadProducts() }
        }
    }

    private var trialSheet: some View {
        TrialOfferSheet(
            isPurchasing: false,
            errorMessage: nil,
            pickedCount: 4,
            freeCap: 2,
            longestStreak: .init(displayName: "Morning run", current: 12, cadence: .daily),
            onStartTrial: {},
            onSeeAllPlans: {},
            onDismiss: {}
        )
    }

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
