import Foundation

enum AppStoreReviewLinks {
    /// App Store Connect numeric ID for Streak Finder.
    static let appStoreID = "6762699692"

    static let displayName = "Streak Finder"

    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    static let feedbackEmail = "jackwallner+fs@gmail.com"
}
