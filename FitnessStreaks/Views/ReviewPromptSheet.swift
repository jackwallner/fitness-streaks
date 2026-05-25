import SwiftUI

struct ReviewPromptSheet: View {
    enum Step {
        case enjoyment
        case reviewPitch
        case feedback
    }

    let initialPresentation: ReviewPromptCoordinator.Presentation
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var step: Step
    @State private var feedbackText = ""
    @State private var pendingNativeReview = false

    private let fromPassiveMoment: Bool

    init(
        initialPresentation: ReviewPromptCoordinator.Presentation,
        onDismiss: (() -> Void)? = nil
    ) {
        self.initialPresentation = initialPresentation
        self.onDismiss = onDismiss
        fromPassiveMoment = initialPresentation.fromPassiveMoment
        _step = State(initialValue: initialPresentation == .feedbackOnly ? .feedback : .enjoyment)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case .enjoyment:
                        enjoymentStep
                    case .reviewPitch:
                        reviewPitchStep
                    case .feedback:
                        feedbackStep
                    }
                }
                .padding(16)
            }
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(headerTitle)
                        .font(RetroFont.pixel(11))
                        .tracking(1)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("CLOSE") { close(markNotNow: fromPassiveMoment && step == .enjoyment) }
                        .font(RetroFont.pixel(10))
                        .foregroundStyle(Theme.retroCyan)
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            onDismiss?()
        }
    }

    private var headerTitle: String {
        switch step {
        case .enjoyment: return "FEEDBACK"
        case .reviewPitch: return "RATE US"
        case .feedback: return "SEND FEEDBACK"
        }
    }

    // MARK: - Steps

    private var enjoymentStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enjoying \(AppStoreReviewLinks.displayName)?")
                .font(RetroFont.pixel(13))
                .foregroundStyle(Theme.retroInk)

            Text("A quick check-in — only if you have a moment.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)

            primaryButton("YES, IT'S GREAT") {
                step = .reviewPitch
            }

            secondaryButton("NOT REALLY") {
                step = .feedback
            }

            tertiaryButton("NOT NOW") {
                close(markNotNow: true)
            }
        }
    }

    private var reviewPitchStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Built solo for streak lovers.")
                .font(RetroFont.pixel(12))
                .foregroundStyle(Theme.retroInk)
            Text("No ads, no account — just your Apple Health streaks on device.")
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInkDim)

            primaryButton("RATE ON APP STORE") {
                ReviewPromptTracker.markOpenedWriteReview()
                openURL(AppStoreReviewLinks.writeReviewURL)
                dismissSheet()
            }

            secondaryButton("MAYBE LATER") {
                pendingNativeReview = true
                ReviewPromptTracker.setPendingNativeReview(true)
                dismissSheet()
            }
        }
    }

    private var feedbackStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make \(AppStoreReviewLinks.displayName) better?")
                .font(RetroFont.pixel(12))
                .foregroundStyle(Theme.retroInk)

            TextEditor(text: $feedbackText)
                .font(RetroFont.mono(12))
                .foregroundStyle(Theme.retroInk)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(10)
                .pixelPanel(color: Theme.retroInkFaint, fill: Theme.retroBgRaised)

            Text("Opens your mail app with this note — nothing is sent automatically.")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)

            primaryButton("SEND FEEDBACK") {
                sendFeedbackMail()
            }
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            tertiaryButton("NOT NOW") {
                close(markNotNow: true)
            }
        }
    }

    // MARK: - Actions

    private func sendFeedbackMail() {
        let body = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppStoreReviewLinks.feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "\(AppStoreReviewLinks.displayName) feedback"),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else { return }
        ReviewPromptTracker.markFeedbackSubmitted()
        openURL(url)
        dismissSheet()
    }

    private func close(markNotNow: Bool) {
        if markNotNow {
            ReviewPromptTracker.markNotNow()
        } else {
            ReviewPromptTracker.markShown()
        }
        dismissSheet()
    }

    private func dismissSheet() {
        ReviewPromptCoordinator.shared.dismiss()
        dismiss()
    }

    // MARK: - Buttons

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.pixel(11))
                .tracking(1)
                .foregroundStyle(Theme.retroBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.retroMagenta)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.pixel(10))
                .tracking(1)
                .foregroundStyle(Theme.retroInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .pixelPanel(color: Theme.retroCyan, fill: Theme.retroBgRaised)
        }
        .buttonStyle(.plain)
    }

    private func tertiaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RetroFont.pixel(10))
                .foregroundStyle(Theme.retroInkDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
