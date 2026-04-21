import SwiftUI

/// Retained wrapper so existing callsites keep working. Delegates to PixelFlame.
struct StreakFlame: View {
    var intensity: CGFloat = 1.0
    var size: CGFloat = 96
    var tint: Color = Theme.retroMagenta

    var body: some View {
        PixelFlame(size: size, intensity: intensity, tint: tint)
    }
}
