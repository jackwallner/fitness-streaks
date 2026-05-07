import SwiftUI

struct CoachmarkStep {
    let anchorID: String?
    let title: String
    let body: String
}

private struct CoachmarkAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func coachmarkAnchor(_ id: String) -> some View {
        anchorPreference(key: CoachmarkAnchorKey.self, value: .bounds) { [id: $0] }
    }

    func coachmarkOverlay(steps: [CoachmarkStep],
                          index: Binding<Int>,
                          isActive: Bool,
                          onFinish: @escaping () -> Void) -> some View {
        overlayPreferenceValue(CoachmarkAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if isActive, steps.indices.contains(index.wrappedValue) {
                    CoachmarkPresenter(
                        anchors: anchors,
                        proxy: proxy,
                        steps: steps,
                        index: index,
                        onFinish: onFinish
                    )
                }
            }
            .allowsHitTesting(isActive)
        }
    }
}

private struct CoachmarkPresenter: View {
    let anchors: [String: Anchor<CGRect>]
    let proxy: GeometryProxy
    let steps: [CoachmarkStep]
    @Binding var index: Int
    var onFinish: () -> Void

    private static let panelWidth: CGFloat = 320
    private static let estimatedPanelHeight: CGFloat = 190
    private static let spotlightInset: CGFloat = -8

    var body: some View {
        let step = steps[index]
        let spotlight: CGRect? = step.anchorID
            .flatMap { anchors[$0] }
            .map { proxy[$0].insetBy(dx: Self.spotlightInset, dy: Self.spotlightInset) }

        ZStack {
            dimmedBackground(spotlight: spotlight)
            spotlightBorder(spotlight: spotlight)
            calloutPanel(step: step, spotlight: spotlight)
        }
        .animation(.easeInOut(duration: 0.22), value: index)
    }

    private func dimmedBackground(spotlight: CGRect?) -> some View {
        let frame = proxy.frame(in: .local)
        return ZStack {
            if let s = spotlight {
                Path { p in
                    p.addRect(frame)
                    p.addRoundedRect(in: s, cornerSize: CGSize(width: 4, height: 4))
                }
                .fill(Color.black.opacity(0.78), style: FillStyle(eoFill: true))
            } else {
                Color.black.opacity(0.78)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    @ViewBuilder
    private func spotlightBorder(spotlight: CGRect?) -> some View {
        if let s = spotlight {
            Rectangle()
                .stroke(Theme.retroLime, lineWidth: 2)
                .frame(width: s.width, height: s.height)
                .position(x: s.midX, y: s.midY)
                .allowsHitTesting(false)
        }
    }

    private func calloutPanel(step: CoachmarkStep, spotlight: CGRect?) -> some View {
        let frame = proxy.frame(in: .local)
        let width = min(frame.width - 28, Self.panelWidth)
        let position = panelPosition(spotlight: spotlight, frame: frame)

        return panelContent(step: step)
            .frame(width: width)
            .position(position)
    }

    private func panelPosition(spotlight: CGRect?, frame: CGRect) -> CGPoint {
        let panelHeight = Self.estimatedPanelHeight
        guard let s = spotlight else {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        let topGap = s.minY - frame.minY
        let bottomGap = frame.maxY - s.maxY
        let needed = panelHeight + 28

        if bottomGap >= needed {
            return CGPoint(x: frame.midX, y: s.maxY + 16 + panelHeight / 2)
        }
        if topGap >= needed {
            return CGPoint(x: frame.midX, y: s.minY - 16 - panelHeight / 2)
        }
        // Neither side has room — place at the side with more space, clamped inside.
        if bottomGap >= topGap {
            let y = min(frame.maxY - panelHeight / 2 - 24, s.maxY + 16 + panelHeight / 2)
            return CGPoint(x: frame.midX, y: y)
        }
        let y = max(frame.minY + panelHeight / 2 + 24, s.minY - 16 - panelHeight / 2)
        return CGPoint(x: frame.midX, y: y)
    }

    private func panelContent(step: CoachmarkStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STEP \(index + 1) / \(steps.count)")
                    .font(RetroFont.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.retroMagenta)
                Spacer()
                Button {
                    onFinish()
                } label: {
                    Text("SKIP")
                        .font(RetroFont.mono(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroInkDim)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip tutorial")
            }

            Text(step.title)
                .font(RetroFont.mono(14, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.retroLime)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.body)
                .font(RetroFont.mono(11))
                .foregroundStyle(Theme.retroInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if index > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            index = max(0, index - 1)
                        }
                    } label: {
                        Text("◀ BACK")
                            .font(RetroFont.mono(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.retroInkDim)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .overlay(Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    advance()
                } label: {
                    Text(index == steps.count - 1 ? "▶ GOT IT" : "▶ NEXT")
                        .font(RetroFont.mono(12, weight: .bold))
                        .foregroundStyle(Theme.retroBg)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(Theme.retroLime)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .pixelPanel(color: Theme.retroLime, fill: Theme.retroBg)
    }

    private func advance() {
        if index >= steps.count - 1 {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                index += 1
            }
        }
    }
}
