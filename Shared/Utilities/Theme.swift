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
    // MARK: - Retro arcade palette (light + dark adaptive)

    static var retroBg: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xf5f2ff))
                : UIColor(Color(hex: 0x0a0612))
        })
        #else
        Color(hex: 0x0a0612)
        #endif
    }
    static var retroBgRaised: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xffffff))
                : UIColor(Color(hex: 0x120a22))
        })
        #else
        Color(hex: 0x120a22)
        #endif
    }
    static var retroBgCard: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xede8fc))
                : UIColor(Color(hex: 0x1e1236))
        })
        #else
        Color(hex: 0x1e1236)
        #endif
    }
    static var retroGrid: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xd8d0ee))
                : UIColor(Color(hex: 0x2a1a4a))
        })
        #else
        Color(hex: 0x2a1a4a)
        #endif
    }

    static var retroInk: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x120824))
                : UIColor(Color(hex: 0xf4ecff))
        })
        #else
        Color(hex: 0xf4ecff)
        #endif
    }
    static var retroInkDim: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x6b5b8a))
                : UIColor(Color(hex: 0x8b7cad))
        })
        #else
        Color(hex: 0x8b7cad)
        #endif
    }
    static var retroInkFaint: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xb0a0cc))
                : UIColor(Color(hex: 0x4a3d6b))
        })
        #else
        Color(hex: 0x4a3d6b)
        #endif
    }

    static var retroMagenta: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc2266))
                : UIColor(Color(hex: 0xff2d95))
        })
        #else
        Color(hex: 0xff2d95)
        #endif
    }
    static var retroCyan: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x0099bb))
                : UIColor(Color(hex: 0x2dd4ff))
        })
        #else
        Color(hex: 0x2dd4ff)
        #endif
    }
    static var retroLime: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x8aaa00))
                : UIColor(Color(hex: 0xc8ff00))
        })
        #else
        Color(hex: 0xc8ff00)
        #endif
    }
    static var retroAmber: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc7a00))
                : UIColor(Color(hex: 0xffb020))
        })
        #else
        Color(hex: 0xffb020)
        #endif
    }
    static var retroRed: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc2233))
                : UIColor(Color(hex: 0xff3b50))
        })
        #else
        Color(hex: 0xff3b50)
        #endif
    }

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
    static let accentHeartRate = Color(hex: 0xff2d55)
    static var accentDistance: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x7044cc))
                : UIColor(Color(hex: 0xb088ff))
        })
        #else
        Color(hex: 0xb088ff)
        #endif
    }
    static var accentFlights: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc5500))
                : UIColor(Color(hex: 0xff7a00))
        })
        #else
        Color(hex: 0xff7a00)
        #endif
    }
    static let accentWorkout = retroRed
    static var accentMindful: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x2a9955))
                : UIColor(Color(hex: 0x7aff9e))
        })
        #else
        Color(hex: 0x7aff9e)
        #endif
    }
    static var accentSleep: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0x0d5599))
                : UIColor(Color(hex: 0x5da9ff))
        })
        #else
        Color(hex: 0x5da9ff)
        #endif
    }
    static var accentEarly: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc6600))
                : UIColor(Color(hex: 0xffa040))
        })
        #else
        Color(hex: 0xffa040)
        #endif
    }
    static var accentIntensity: Color {
        #if os(iOS)
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(Color(hex: 0xcc3366))
                : UIColor(Color(hex: 0xff5a8f))
        })
        #else
        Color(hex: 0xff5a8f)
        #endif
    }

    static let cardRadius: CGFloat = 0
    static let cardPadding: CGFloat = 16

    static var streakGradient: LinearGradient {
        LinearGradient(colors: [retroLime, retroMagenta], startPoint: .topLeading, endPoint: .bottomTrailing)
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
    // Former pixel-font callsites now render in JetBrains Mono Bold.
    // Kept as a shim so existing views compile unchanged.
    static func pixel(_ size: CGFloat) -> Font {
        mono(size, weight: .bold)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = size * 1.25
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
        case .medium, .semibold:    name = "JetBrainsMono-Medium"
        default:                    name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: scaledSize)
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
