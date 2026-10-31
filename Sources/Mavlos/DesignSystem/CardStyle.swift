import SwiftUI

/// Superficie card con angoli arrotondati 12–18 px, bordo sottilissimo e
/// ombra morbida riverberata.
struct CardModifier: ViewModifier {
    var radius: CGFloat = 14
    var fill: Color = Palette.cardFill

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func card(radius: CGFloat = 14, fill: Color? = nil) -> some View {
        modifier(CardModifier(radius: radius, fill: fill ?? Palette.cardFill))
    }
}

/// Riga cliccabile con riflessèo hover leggero.
struct HoverBackground: ViewModifier {
    var cornerRadius: CGFloat = 10

    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hovering ? Palette.rowHover : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverRow(cornerRadius: CGFloat = 10) -> some View {
        modifier(HoverBackground(cornerRadius: cornerRadius))
    }
}
