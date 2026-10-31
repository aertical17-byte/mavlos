import SwiftUI

/// Sfondo ambientale condiviso: base scura #101114 con bagliori radiali
/// morbi (blu alto-sinistra, viola alto-destra, marrone caldo basso-centro).
/// I gradienti sono sfumati e poco invasivi, per non compromettere la
/// leggibilità dei contenuti.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0C0D10)

            AmbientBlob(
                color: Palette.ambientBlue,
                center: UnitPoint(x: 0.02, y: -0.06),
                radius: 640,
                opacity: 0.9
            )
            AmbientBlob(
                color: Palette.ambientPurple,
                center: UnitPoint(x: 1.05, y: -0.04),
                radius: 580,
                opacity: 0.75
            )
            AmbientBlob(
                color: Palette.ambientWarm,
                center: UnitPoint(x: 0.58, y: 1.34),
                radius: 680,
                opacity: 0.62
            )

            // Velo scuro al centro: amplia la leggibilità delle superfici.
            RadialGradient(
                colors: [Color.black.opacity(0.45), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.58),
                startRadius: 240,
                endRadius: 1020
            )
        }
        .ignoresSafeArea()
    }
}

private struct AmbientBlob: View {
    let color: Color
    let center: UnitPoint
    let radius: CGFloat
    let opacity: Double

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(opacity), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .position(
                    x: center.x * geometry.size.width,
                    y: center.y * geometry.size.height
                )
                .blur(radius: 90)
        }
        .ignoresSafeArea()
    }
}

/// Vetro sidebar (AppKit): sfuma il contenuto della finestra dietro la
/// navigazione, per l'effetto "frosted glass" di macOS.
struct SidebarGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .withinWindow
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
