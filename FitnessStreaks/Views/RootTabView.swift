import SwiftUI

enum RootTab: Hashable {
    case streaks, saves, stats
}

struct RootTabView: View {
    @State private var selection: RootTab = .streaks

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .padding(.bottom, 64)  // leave room for the pixel tab bar

            PixelTabBar(selection: $selection)
        }
        .background(Theme.retroBg.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .streaks: DashboardView()
        case .saves:   SavesView()
        case .stats:   StatsView()
        }
    }
}

private struct PixelTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 0) {
            tab(.streaks, label: "STREAKS", symbol: "flame.fill", accent: Theme.retroMagenta)
            tab(.saves,   label: "SAVES",   symbol: "shield.lefthalf.filled", accent: Theme.retroLime)
            tab(.stats,   label: "STATS",   symbol: "chart.bar.fill", accent: Theme.retroCyan)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            Rectangle()
                .fill(Theme.retroBg)
                .overlay(
                    Rectangle()
                        .fill(Theme.retroInkFaint)
                        .frame(height: 2),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ tab: RootTab, label: String, symbol: String, accent: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selection == tab ? accent : Theme.retroInkDim)
                Text(label)
                    .font(RetroFont.pixel(8))
                    .tracking(1)
                    .foregroundStyle(selection == tab ? accent : Theme.retroInkDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                if selection == tab {
                    Rectangle()
                        .fill(accent)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.capitalized)
    }
}
