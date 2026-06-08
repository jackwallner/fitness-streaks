import Foundation

enum AppStoreReviewLinks {
    /// App Store Connect numeric ID for Streaks.
    static let appStoreID = "6762699692"

    static let displayName = "Streaks"

    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    static let feedbackEmail = "jackwallner+fs@gmail.com"
}
