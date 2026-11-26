import XCTest

/// Ask to Buy: a purchase waiting for approval is a calm state, not an error.
final class PurchasePendingTests: XCTestCase {
    /// RevenueCat's `ErrorCode.paymentPendingError` as it reaches the app.
    private func revenueCat(code: Int) -> NSError {
        NSError(domain: PurchaseErrorMapping.revenueCatDomain, code: code)
    }

    func testPaymentPendingErrorIsAwaitingApproval() {
        XCTAssertTrue(PurchaseErrorMapping.isAwaitingApproval(revenueCat(code: 20)))
    }

    func testNetworkErrorIsNotPending() {
        XCTAssertFalse(PurchaseErrorMapping.isAwaitingApproval(revenueCat(code: 10)))
        XCTAssertFalse(PurchaseErrorMapping.isAwaitingApproval(revenueCat(code: 35)))
    }

    func testOtherErrorsAreUnchanged() {
        for code in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 21] {
            XCTAssertFalse(PurchaseErrorMapping.isAwaitingApproval(revenueCat(code: code)), "code \(code)")
        }
        XCTAssertFalse(PurchaseErrorMapping.isAwaitingApproval(URLError(.notConnectedToInternet)))
    }

    func testSameCodeInAnotherDomainIsNotPending() {
        XCTAssertFalse(PurchaseErrorMapping.isAwaitingApproval(NSError(domain: "Other", code: 20)))
    }

    func testPendingMessageCopy() {
        XCTAssertEqual(
            PurchaseErrorMapping.awaitingApprovalMessage,
            "Waiting for approval. Your purchase unlocks once it is approved."
        )
    }

    func testPendingMessageIsTranslatedEverywhere() throws {
        let key = "Waiting for approval. Your purchase unlocks once it is approved."
        for language in ["de", "es", "nl", "ru", "vi", "zh-Hans"] {
            let hosts = [Bundle.main] + Bundle.allBundles
            let path = try XCTUnwrap(hosts.compactMap { $0.path(forResource: language, ofType: "lproj") }.first, language)
            let bundle = try XCTUnwrap(Bundle(path: path))
            let text = bundle.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(text, key, "\(language) has no translation")
        }
    }
}
