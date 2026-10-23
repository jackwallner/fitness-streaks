import CoreGraphics
import XCTest

/// The unfolded iPhone Duo split: when the tabs and the streak detail get
/// their own panes, and where the panes meet the fold.
final class UnfoldedSplitTests: XCTestCase {
    /// The unfolded inner display, held landscape.
    private let innerWidth: CGFloat = 951

    func testCompactWidthNeverSplits() {
        XCTAssertNil(UnfoldedSplit.make(width: 466, isRegularWidth: false, fold: nil))
        XCTAssertNil(UnfoldedSplit.make(width: innerWidth, isRegularWidth: false, fold: 465...486))
    }

    func testPortraitUnfoldStaysSingleColumn() {
        // 669 pt wide: two 360 pt panes do not fit.
        XCTAssertNil(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil))
    }

    func testPanesMeetTheFoldEdges() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 465...486))
        XCTAssertEqual(split.primaryWidth, 465)
        XCTAssertEqual(split.secondaryX, 486)
        XCTAssertEqual(split.secondaryWidth, innerWidth - 486)
    }

    func testMeasuredSimulatorFoldBesideTheVerticalBar() throws {
        // gh-sim iPhone Duo: an 867 pt root (84 pt system bar on the trailing
        // edge) with the fold at 455.5...495.5.
        let split = try XCTUnwrap(UnfoldedSplit.make(width: 867, isRegularWidth: true, fold: 455.5...495.5))
        XCTAssertEqual(split.primaryWidth, 455.5)
        XCTAssertEqual(split.secondaryX, 495.5)
        XCTAssertEqual(split.secondaryWidth, 371.5)
    }

    func testMeasuredSimulatorFoldWithHorizontalPaneToolbars() throws {
        // With horizontal pane toolbars the system drops its vertical bar: the
        // root is the full 951 pt and the panes mirror each other.
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 455.5...495.5))
        XCTAssertEqual(split.primaryWidth, 455.5)
        XCTAssertEqual(split.secondaryX, 495.5)
        XCTAssertEqual(split.secondaryWidth, split.primaryWidth)
    }

    func testZeroWidthFoldStillMeetsIt() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: 475...475))
        XCTAssertEqual(split.primaryWidth, 475)
        XCTAssertEqual(split.secondaryX, 475)
        XCTAssertEqual(split.primaryWidth + split.secondaryWidth, innerWidth)
    }

    func testNoFoldSplitsEvenly() throws {
        let split = try XCTUnwrap(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: nil))
        XCTAssertEqual(split.primaryWidth, 475)
        XCTAssertEqual(split.secondaryX, 475)
        XCTAssertEqual(split.secondaryWidth, 476)
    }

    func testOffCentreFoldFallsBackToAnEvenSplit() throws {
        // A fold that would leave the trailing pane under 360 pt is ignored.
        let split = try XCTUnwrap(UnfoldedSplit.make(width: 800, isRegularWidth: true, fold: 500...510))
        XCTAssertEqual(split.primaryWidth, 400)
        XCTAssertEqual(split.secondaryX, 400)
    }

    func testEverySplitKeepsBothPanesUsableAndCoversTheWidth() {
        for width in stride(from: CGFloat(600), through: 1400, by: 7) {
            guard let split = UnfoldedSplit.make(width: width, isRegularWidth: true, fold: nil) else {
                XCTAssertLessThan(width, UnfoldedSplit.minimumPaneWidth * 2)
                continue
            }
            XCTAssertGreaterThanOrEqual(split.primaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertGreaterThanOrEqual(split.secondaryWidth, UnfoldedSplit.minimumPaneWidth)
            XCTAssertEqual(split.secondaryX + split.secondaryWidth, width)
        }
    }
}

/// The selected card's ring stays inside the card (rejected 2026-10-23: drawn
/// 4 pt outside, it overran the pane margin and halved the grid gutter).
final class PaneSelectionRingTests: XCTestCase {
    /// A badge card in the leading pane's two-column grid.
    private let card = CGRect(x: 6, y: 0, width: 220, height: 120)
    private let cardBorderWidth: CGFloat = 2
    private let badgeContentPadding: CGFloat = 10

    func testRingStaysInsideTheCard() {
        XCTAssertTrue(card.contains(PaneSelectionRing.strokeBounds(in: card)))
    }

    func testRingClearsTheCardBorder() {
        // The card's border stroke reaches half its width inside the edge.
        let borderInner = card.insetBy(dx: cardBorderWidth / 2, dy: cardBorderWidth / 2)
        let ring = PaneSelectionRing.strokeBounds(in: card)
        XCTAssertGreaterThan(ring.minX, borderInner.minX)
        XCTAssertLessThan(ring.maxX, borderInner.maxX)
    }

    func testRingClearsTheCardContent() {
        let ringInnerEdge = PaneSelectionRing.inset + PaneSelectionRing.lineWidth / 2
        XCTAssertLessThan(ringInnerEdge, badgeContentPadding)
    }
}
