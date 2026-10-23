import CoreGraphics

/// Pane frames for the unfolded iPhone Duo: the tabs (with the tab bar) on the
/// leading side of the fold and the streak they open on the trailing side, so
/// nothing straddles the crease. `nil` keeps the single column (every ordinary
/// iPhone, the folded Duo, and the unfolded Duo held in portrait, where each
/// half would be too narrow).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the phone layout of every tab.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

/// The ring on the card whose streak fills the pane beside the list. It sits
/// inside the card, a gap in from the card's own border, so the selected card
/// keeps the same outline, margins and grid gutter as its neighbours.
enum PaneSelectionRing {
    static let lineWidth: CGFloat = 2
    /// Distance from the card's edge to the centre of the ring's stroke.
    static let inset: CGFloat = 4

    /// The area the stroke covers, for a card of the given bounds.
    static func strokeBounds(in card: CGRect) -> CGRect {
        card.insetBy(dx: inset - lineWidth / 2, dy: inset - lineWidth / 2)
    }
}
