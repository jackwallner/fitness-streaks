import SwiftUI

enum Theme {
    // MARK: - Adaptive base

    #if os(watchOS)
    static let background = Color.black
    static let cardSurface = Color(white: 0.12)
    static let cardSurfaceLight = Color(white: 0.18)
    static let ringTrack = Color(white: 0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
    static let textTertiary = Color(white: 0.5)
    #else
    static let background = Color(.systemBackground)
    static let cardSurface = Color(.secondarySystemBackground)
    static let cardSurfaceLight = Color(.tertiarySystemBackground)
    static let ringTrack = Color(.systemFill)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    #endif

    // MARK: - Streak palette (fire → ember)

    static let streakHot = Color(red: 1.00, green: 0.37, blue: 0.22)        // #FF5E37 vivid ember
    static let streakGlow = Color(red: 1.00, green: 0.58, blue: 0.10)       // #FF9419 warm flame
    static let streakCool = Color(red: 0.95, green: 0.78, blue: 0.30)       // #F2C74D embered gold

    // Per-metric accents (distinct + complementary to streak fire)
    static let accentSteps = Color(red: 0.24, green: 0.73, blue: 0.70)      // teal
    static let accentExercise = Color(red: 0.36, green: 0.78, blue: 0.46)   // green
    static let accentStand = Color(red: 0.40, green: 0.70, blue: 0.98)      // sky
    static let accentEnergy = Color(red: 1.00, green: 0.42, blue: 0.42)     // coral
    static let accentWorkout = Color(red: 0.62, green: 0.40, blue: 0.82)    // purple
    static let accentMindful = Color(red: 0.55, green: 0.72, blue: 0.85)    // soft blue
    static let accentSleep = Color(red: 0.48, green: 0.52, blue: 0.82)      // indigo
    static let accentDistance = Color(red: 0.20, green: 0.60, blue: 0.85)   // blue
    static let accentFlights = Color(red: 0.85, green: 0.55, blue: 0.35)    // bronze

    // MARK: - Constants
    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 20

    // MARK: - Gradients
    static var streakGradient: LinearGradient {
        LinearGradient(colors: [streakHot, streakGlow], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func gradient(for accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Typography
    static func bigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
