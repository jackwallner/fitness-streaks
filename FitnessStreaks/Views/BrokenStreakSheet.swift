import SwiftUI

struct BrokenStreakSheet: View {
    let broken: BrokenStreak
    let restart: () -> Void
    let pickNew: () -> Void
    let dismiss: () -> Void

    @Environment(\.dismiss) private var close

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                PixelFlame(size: 64, intensity: 0.5, tint: Theme.retroRed)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("STREAK ENDED")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroRed)
                    Text("Your \(broken.metric.displayName.lowercased()) run ended at \(broken.brokenLength) \(broken.cadence.pluralLabel). Restart the same goal or pick a new one.")
                        .font(RetroFont.mono(12))
                        .foregroundStyle(Theme.retroInk)
                        .lineSpacing(3)
                }
                .padding(14)
                .pixelPanel(color: Theme.retroRed, fill: Theme.retroBgRaised)

                Button {
                    restart()
                    close()
                } label: {
                    Text("RESTART SAME GOAL")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroBg)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Theme.retroLime)
                }
                .buttonStyle(.plain)

                Button {
                    pickNew()
                    close()
                } label: {
                    Text("PICK A NEW GOAL")
                        .font(RetroFont.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.retroCyan)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().stroke(Theme.retroCyan, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(16)
            .background(Theme.retroBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RECOVERY")
                        .font(RetroFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.retroMagenta)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        close()
                    } label: {
                        Text("CLOSE")
                            .font(RetroFont.mono(10, weight: .bold))
                            .foregroundStyle(Theme.retroInkDim)
                    }
                }
            }
            .toolbarBackground(Theme.retroBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
