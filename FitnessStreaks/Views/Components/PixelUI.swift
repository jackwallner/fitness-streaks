import SwiftUI

// MARK: - PixelFlame
// 8×8 sprite rendered via Canvas. Intensity controls glow radius.
struct PixelFlame: View {
    var size: CGFloat = 56
    var intensity: CGFloat = 1.0
    var tint: Color = Theme.retroMagenta

    // X = tint, W = white hot core, . = transparent
    private static let grid: [[Character]] = [
        [".", ".", ".", "X", "X", ".", ".", "."],
        [".", ".", "X", "X", "X", "X", ".", "."],
        [".", "X", "X", "W", "X", "X", "X", "."],
        ["X", "X", "W", "W", "W", "X", "X", "X"],
        ["X", "W", "W", "W", "W", "W", "X", "X"],
        ["X", "X", "W", "W", "W", "X", "X", "X"],
        [".", "X", "X", "X", "X", "X", "X", "."],
        [".", ".", "X", "X", "X", "X", ".", "."]
    ]

    var body: some View {
        let cell = size / 8
        Canvas { ctx, _ in
            for (r, row) in Self.grid.enumerated() {
                for (c, ch) in row.enumerated() {
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    switch ch {
                    case "X": ctx.fill(Path(rect), with: .color(tint))
                    case "W": ctx.fill(Path(rect), with: .color(.white))
                    default: continue
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.7), radius: 6 + 10 * max(0, min(intensity, 1)))
    }
}

// MARK: - PixelProgressBar (segmented)

struct PixelProgressBar: View {
    var progress: Double // 0...1
    var accent: Color = Theme.retroAmber
    var segments: Int = 20
    var height: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let gap: CGFloat = 1
            let inset: CGFloat = 2
            let inner = total - inset * 2
            let segW = max(0, (inner - CGFloat(segments - 1) * gap) / CGFloat(segments))
            let filled = Int((Double(segments) * max(0, min(progress, 1))).rounded(.down))

            ZStack {
                Rectangle().fill(Theme.retroBg)
                Rectangle().stroke(Theme.retroInkFaint, lineWidth: 2)
                HStack(spacing: gap) {
                    ForEach(0..<segments, id: \.self) { i in
                        Rectangle()
                            .fill(i < filled ? accent : Color.clear)
                            .frame(width: segW)
                            .overlay(alignment: .top) {
                                if i < filled {
                                    Rectangle().fill(Color.white.opacity(0.25)).frame(height: 2)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if i < filled {
                                    Rectangle().fill(Color.black.opacity(0.3)).frame(height: 2)
                                }
                            }
                    }
                }
                .padding(inset)
            }
        }
        .frame(height: height)
    }
}

// MARK: - PixelBarThin (smooth, used in badge cards)

struct PixelBarThin: View {
    var progress: Double
    var accent: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.retroBg)
                Rectangle()
                    .fill(accent)
                    .frame(width: geo.size.width * max(0, min(progress, 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - PixelButton

struct PixelButton: View {
    var title: String
    var accent: Color = Theme.retroLime
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(RetroFont.pixel(12))
                .tracking(1)
                .foregroundStyle(Theme.retroBg)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(accent)
                .overlay(
                    Rectangle().stroke(Color.white.opacity(pressed ? 0 : 0.25), lineWidth: 2)
                        .padding(2)
                )
                .overlay(Rectangle().stroke(accent, lineWidth: 2))
                .offset(x: pressed ? 1 : 0, y: pressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - PixelToggle

struct PixelToggle: View {
    @Binding var isOn: Bool
    var accent: Color = Theme.retroMagenta

    var body: some View {
        Button {
            withAnimation(.linear(duration: 0.12)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Rectangle()
                    .fill(isOn ? accent : Theme.retroBg)
                Rectangle()
                    .stroke(isOn ? accent : Theme.retroInkFaint, lineWidth: 2)
                Rectangle()
                    .fill(isOn ? Theme.retroBg : Theme.retroInkFaint)
                    .frame(width: 16, height: 14)
                    .padding(2)
            }
            .frame(width: 44, height: 22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PixelChip

struct PixelChip: View {
    var text: String
    var accent: Color = Theme.retroCyan

    var body: some View {
        Text(text.uppercased())
            .font(RetroFont.pixel(9))
            .tracking(1)
            .foregroundStyle(Theme.retroBg)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(accent)
    }
}

// MARK: - Section header

struct PixelSectionHeader: View {
    var title: String

    var body: some View {
        Text("■ " + title.uppercased())
            .font(RetroFont.pixel(10))
            .tracking(2)
            .foregroundStyle(Theme.retroInkDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
    }
}

// MARK: - Blinking text (for INSERT COIN)

struct BlinkingText: View {
    let text: String
    var font: Font = RetroFont.pixel(10)
    var color: Color = Theme.retroCyan
    var tracking: CGFloat = 4

    @State private var visible = true

    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(color)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
