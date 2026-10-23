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

/// A cell of the Dashboard's streak grid.
enum DashboardGridCell: Hashable, Identifiable {
    case streak(Streak)
    case findMore

    var id: String {
        switch self {
        case .streak(let streak): return streak.id
        case .findMore: return "findMore"
        }
    }

    /// Folded, the hero keeps its big card above the grid and Find More sits
    /// below it. Beside the fold the pane is only 669 pt tall and the detail
    /// pane already shows the hero in full, so the hero leads the grid as a
    /// card and Find More fills the last cell: every card ends above the tab bar.
    static func cells(hero: Streak?, badges: [Streak], isSplit: Bool) -> [DashboardGridCell] {
        guard isSplit else { return badges.map(DashboardGridCell.streak) }
        let streaks = ([hero].compactMap { $0 } + badges).map(DashboardGridCell.streak)
        return streaks + [.findMore]
    }
}
