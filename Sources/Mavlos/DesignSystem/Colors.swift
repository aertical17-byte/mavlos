import SwiftUI
import MavlosCore

extension Color {
    /// Converte un esadecimale 0xRRGGBB in colore sRGB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

/// Palette ufficiale di Mavlos (PRD §2): scura, ambientale, con superfici
/// e testi calibrati su macOS.
enum Palette {
    // Superfici
    static let windowBackground = Color(hex: 0x101114)
    static let panelDark = Color(hex: 0x1B1B20)
    static let sidebarTint = Color(hex: 0x26384F)
    static let cardFill = Color(hex: 0x343438)
    static let cardFillHover = Color(hex: 0x3E3E43)
    static let rowHover = Color.white.opacity(0.045)
    static let hairline = Color.white.opacity(0.07)
    static let hairlineStrong = Color.white.opacity(0.12)

    // Testi
    static let primaryText = Color(hex: 0xF2F0F1)
    static let secondaryText = Color(hex: 0xA5A2A6)
    static let mutedText = Color(hex: 0x858388)

    // Accenti di feedback
    static let accentBlue = Color(hex: 0x69A8FF)
    static let warningAmber = Color(hex: 0xD98E4A)
    static let dangerRed = Color(hex: 0xE07A6C)
    static let successGreen = Color(hex: 0x69C591)

    // Ambienti (bagliori dello sfondo)
    static let ambientBlue = Color(hex: 0x2C4E8E)
    static let ambientPurple = Color(hex: 0x533A78)
    static let ambientWarm = Color(hex: 0x6B4526)

    // Categorie
    static let categoryImages = Color(hex: 0x69A8FF)
    static let categoryDocuments = Color(hex: 0xE9B64F)
    static let categoryMusic = Color(hex: 0x69C591)
    static let categoryVideo = Color(hex: 0xA58BEA)
    static let categoryArchives = Color(hex: 0xC9A27A)
    static let categoryOthers = Color(hex: 0x9C9BA4)

    static func color(for category: FileCategory) -> Color {
        switch category {
        case .images: return categoryImages
        case .documents: return categoryDocuments
        case .music: return categoryMusic
        case .video: return categoryVideo
        case .archives: return categoryArchives
        case .others: return categoryOthers
        }
    }
}
