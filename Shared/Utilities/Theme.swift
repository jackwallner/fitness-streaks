import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self = Color(red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Theme {
    // MARK: - Retro arcade palette (dark-only)

    static let retroBg        = Color(hex: 0x0a0612)
    static let retroBgRaised  = Color(hex: 0x120a22)
    static let retroBgCard    = Color(hex: 0x1e1236)
    static let retroGrid      = Color(hex: 0x2a1a4a)

    static let retroInk       = Color(hex: 0xf4ecff)
    static let retroInkDim    = Color(hex: 0x8b7cad)
    static let retroInkFaint  = Color(hex: 0x4a3d6b)

    static let retroMagenta   = Color(hex: 0xff2d95)
    static let retroCyan      = Color(hex: 0x2dd4ff)
    static let retroLime      = Color(hex: 0xc8ff00)
    static let retroAmber     = Color(hex: 0xffb020)
    static let retroRed       = Color(hex: 0xff3b50)

    // MARK: - Legacy aliases (keep existing callsites compiling)

    static let background = retroBg
    static let cardSurface = retroBgRaised
    static let cardSurfaceLight = retroBgCard
    static let ringTrack = retroInkFaint
    static let textPrimary = retroInk
    static let textSecondary = retroInkDim
    static let textTertiary = retroInkFaint

    static let streakHot = retroMagenta
    static let streakGlow = retroAmber
    static let streakCool = retroLime

    static let accentSteps = retroLime
    static let accentExercise = retroMagenta
    static let accentStand = retroCyan
    static let accentEnergy = retroAmber
    static let accentDistance = Color(hex: 0xb088ff)
    static let accentFlights = Color(hex: 0xff7a00)
    static let accentWorkout = retroRed
    static let accentMindful = Color(hex: 0x7aff9e)
    static let accentSleep = Color(hex: 0x5da9ff)

    static let cardRadius: CGFloat = 0
    static let cardPadding: CGFloat = 16

    static var streakGradient: LinearGradient {
        LinearGradient(colors: [retroMagenta, retroAmber], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func gradient(for accent: Color) -> LinearGradient {
        LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func bigNumber(_ size: CGFloat) -> Font {
        RetroFont.pixel(size)
    }
}

// MARK: - Retro typography

enum RetroFont {
    static func pixel(_ size: CGFloat) -> Font {
        .custom("PressStart2P-Regular", size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
        case .medium, .semibold:    name = "JetBrainsMono-Medium"
        default:                    name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Pixel panel styling

struct PixelPanelStyle: ViewModifier {
    var color: Color = Theme.retroInkFaint
    var fill: Color = Theme.retroBgRaised
    var lineWidth: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().stroke(color, lineWidth: lineWidth))
    }
}

extension View {
    func pixelPanel(color: Color = Theme.retroInkFaint,
                    fill: Color = Theme.retroBgRaised,
                    lineWidth: CGFloat = 2) -> some View {
        modifier(PixelPanelStyle(color: color, fill: fill, lineWidth: lineWidth))
    }

    func retroGlow(_ color: Color, radius: CGFloat = 14) -> some View {
        self
            .shadow(color: color.opacity(0.6), radius: radius)
            .shadow(color: Theme.retroBg, radius: 0, x: 3, y: 3)
    }
}
