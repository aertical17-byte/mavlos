import SwiftUI

/// Tipografia di Mavlos: tabulari e monospace (SF Mono) per percorsi,
/// testo e numeri tecnici; SF Pro per titoli e microcopy.
enum Typefaces {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let brand = mono(15, .semibold)
    static let navItem = sans(13, .medium)

    static let heroTitle = sans(40, .bold)
    static let pageTitle = sans(30, .bold)
    static let sectionTitle = sans(20, .semibold)
    static let resultsTitle = sans(27, .bold)

    static let bodyText = sans(14)
    static let description = sans(14.5)
    static let small = sans(12)
    static let micro = sans(11)

    static let rowTitle = sans(15, .semibold)
    static let rowValue = sans(14)
    static let rowSubtitle = mono(11.5)

    static let statNumber = sans(27, .bold)
    static let statValue = mono(12.5)
    static let footerMono = mono(11)
    static let sectionLabel = mono(11)
    static let chip = mono(10, .semibold)
}
