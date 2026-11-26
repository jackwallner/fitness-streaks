import Foundation
import XCTest

/// The rating-ask rules from the fleet policy: ask from the second launch,
/// wait out a 30-day cooldown, stop only when the user opened the review page,
/// and never let feedback stop or restart the asks.
@MainActor
final class ReviewPromptTrackerTests: XCTestCase {
    /// Snapshots and restores the tracker's persisted state so the suite
    /// doesn't leave a simulator install mid-ask.
    private func withCleanTracker(_ body: () -> Void) {
        let launches = ReviewPromptTracker.appLaunchCount
        let lastShown = ReviewPromptTracker.lastShownDate
        let outcome = ReviewPromptTracker.outcome
        let pending = ReviewPromptTracker.hasPendingPositiveMoment
        defer {
            ReviewPromptTracker.appLaunchCount = launches
            ReviewPromptTracker.lastShownDate = lastShown
            ReviewPromptTracker.outcome = outcome
            ReviewPromptTracker.hasPendingPositiveMoment = pending
        }
        ReviewPromptTracker.outcome = nil
        ReviewPromptTracker.lastShownDate = nil
        ReviewPromptTracker.hasPendingPositiveMoment = false
        body()
    }

    func testAsksFromTheSecondSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    func testNeverAsksInTheFirstSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 1
            XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    func testStillRequiresFinishedOnboarding() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: false))
        }
    }

    func testOpeningTheReviewPageEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markOpenedWriteReview()
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-365 * 86_400)
            XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    func testWaitsOutTheCooldown() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-10 * 86_400)
            XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-31 * 86_400)
            XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    func testFeedbackNeverEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markFeedbackSubmitted()
            XCTAssertEqual(ReviewPromptTracker.outcome, .submittedFeedback)
            XCTAssertNil(ReviewPromptTracker.lastShownDate, "feedback must not start a cooldown")
            XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    func testFeedbackAfterTheReviewPageKeepsTheAsksEnded() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markOpenedWriteReview()
            ReviewPromptTracker.markFeedbackSubmitted()
            XCTAssertEqual(ReviewPromptTracker.outcome, .openedWriteReview)
            XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    /// A moment whose ask finds a sheet open must survive that skip so the
    /// sheet's dismissal can still ask.
    func testBlockedAskKeepsTheMomentPending() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.recordPositiveMoment()
            XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.markShown()
            XCTAssertFalse(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }
}

/// The good results that may ask: a grown or newly met hero streak asks, a
/// slip or an unchanged streak does not.
final class ReviewMomentTests: XCTestCase {
    private func hero(_ key: String, _ current: Int, done: Bool) -> ReviewMoment.Hero {
        .init(key: key, current: current, unitCompleted: done)
    }

    private func hero(_ current: Int, done: Bool) -> ReviewMoment.Hero {
        hero("steps", current, done: done)
    }

    func testGoalNewlyMetInsideARunAsks() {
        XCTAssertTrue(ReviewMoment.isGoodResult(previous: hero(5, done: false), new: hero(6, done: true)))
        XCTAssertTrue(ReviewMoment.isGoodResult(previous: hero(5, done: false), new: hero(5, done: true)))
    }

    func testGrownStreakAsks() {
        XCTAssertTrue(ReviewMoment.isGoodResult(previous: hero(4, done: true), new: hero(5, done: true)))
    }

    func testBrokenOrShrunkStreakDoesNotAsk() {
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(8, done: true), new: hero(0, done: false)))
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(8, done: true), new: hero(3, done: false)))
    }

    func testUnchangedStreakDoesNotAsk() {
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(5, done: true), new: hero(5, done: true)))
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(5, done: false), new: hero(5, done: false)))
    }

    func testShortRunDoesNotAsk() {
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(1, done: false), new: hero(1, done: true)))
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(1, done: true), new: hero(2, done: true)))
    }

    func testNewHeroOrNoHeroDoesNotAsk() {
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero("steps", 5, done: false), new: hero("sleep", 9, done: true)))
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: nil, new: hero(5, done: true)))
        XCTAssertFalse(ReviewMoment.isGoodResult(previous: hero(5, done: false), new: nil))
    }
}
