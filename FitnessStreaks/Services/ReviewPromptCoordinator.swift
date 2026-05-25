import SwiftUI

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation: Identifiable, Equatable {
        case enjoyment(fromPassiveMoment: Bool)
        case feedbackOnly

        var id: String {
            switch self {
            case .enjoyment: return "enjoyment"
            case .feedbackOnly: return "feedback"
            }
        }

        var fromPassiveMoment: Bool {
            if case .enjoyment(let passive) = self { return passive }
            return false
        }
    }

    @Published var activePresentation: Presentation?

    private init() {}

    func requestEnjoymentPrompt(bypassPassiveGates: Bool = false) {
        guard ReviewPromptTracker.canPresentEnjoymentPrompt(
            hasCompletedSetup: StreakSettings.shared.hasCompletedSetup,
            bypassPassiveGates: bypassPassiveGates
        ) else { return }
        if !bypassPassiveGates {
            ReviewPromptTracker.markShown()
        }
        activePresentation = .enjoyment(fromPassiveMoment: !bypassPassiveGates)
    }

    func requestFeedback(bypassPassiveGates: Bool = true) {
        guard ReviewPromptTracker.canPresentEnjoymentPrompt(
            hasCompletedSetup: StreakSettings.shared.hasCompletedSetup,
            bypassPassiveGates: bypassPassiveGates
        ) else { return }
        activePresentation = .feedbackOnly
    }

    func dismiss() {
        activePresentation = nil
    }
}
