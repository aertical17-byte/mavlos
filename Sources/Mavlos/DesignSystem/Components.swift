import SwiftUI
import AppKit
import MavlosCore

// MARK: - Risorse

/// Accesso alle risorse grafiche incluse nel bundle dell'app.
/// La mascotte vive in `Assets/mavlos-mascot.png` e viene copiata nel bundle
/// dalla script di packaging.
enum AppAssets {
    static let mascot: NSImage? = Bundle.main.image(forResource: "mavlos-mascot")
}

// MARK: - Mascotte

struct MascotBadge: View {
    var size: CGFloat = 44
    var cornerRadius: CGFloat?

    var body: some View {
        Group {
            if let image = AppAssets.mascot {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Color(hex: 0xE7E2DA))
                    Image(systemName: "cpu")
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: size * 0.16, x: 0, y: size * 0.08)
    }
}

// MARK: - Pulsanti

/// Pulsante con feedback visivo: primario chiaro, secondario scuro.
/// Mette in evidenza il through di hover discreto al passaggio.
struct ActionButton: View {
    enum Kind {
        case primary, secondary

        var fill: Color {
            self == .primary ? Color(hex: 0xF5F3F5) : Color(hex: 0x3A3A3F)
        }

        var hoverFill: Color {
            self == .primary ? Color(hex: 0xE6E3E6) : Color(hex: 0x46464C)
        }

        var foreground: Color {
            self == .primary ? Color(hex: 0x15151A) : Palette.primaryText
        }
    }

    let kind: Kind
    let title: String
    var icon: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(Typefaces.mono(13, .semibold))
            }
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering ? kind.hoverFill : kind.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        kind == .primary ? Color.white.opacity(0.55) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                self.hovering = hovering
            }
        }
    }
}

// MARK: - Toggle

/// Interruttore moderno nello stile degli screenshot: pillola con manopola,
/// bianca quando attiva e scura quando disattiva.
struct MavlosToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isOn ? Color(hex: 0xEDEAED) : Color(hex: 0x2F2F34))
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(isOn ? Color(hex: 0x17171B) : Color(hex: 0xB9B7BD))
                    .frame(width: 20, height: 20)
                    .padding(3)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isOn ? Color.clear : Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Checkbox

/// Casella di selezione allungata con angoli morbidi e segno spuntato nero
/// su sfondo bianco quando selezionata.
struct SelectionBox: View {
    let checked: Bool
    var size: CGFloat = 21

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(checked ? Color.white : Color.white.opacity(0.05))

            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Color(hex: 0x16161A))
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.4)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tipografia di comodo

struct MonoValue: View {
    let text: String
    var size: CGFloat = 11.5
    var color: Color = Palette.secondaryText

    init(_ text: String, size: CGFloat = 11.5, color: Color = Palette.secondaryText) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Typefaces.mono(size, .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// Etichetta di sezione ("cartelle", "comportamento", "regole"): minuscole
/// monospaziate, molto discreta.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Typefaces.mono(11))
            .kerning(0.6)
            .foregroundStyle(Palette.primaryText.opacity(0.45))
    }
}

/// Pallino colorato condiviso da categorie e regole.
struct CategoryDot: View {
    let color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Badge di avviso (conflitti, da verificare, permessi).
struct WarningChip: View {
    let text: String
    var color: Color = Palette.warningAmber

    var body: some View {
        Text(text)
            .font(Typefaces.mono(10, .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.13)))
    }
}

// MARK: - Stato vuoto

struct EmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            MascotBadge(size: 84)
            Text(title)
                .font(Typefaces.sectionTitle)
                .foregroundStyle(Palette.primaryText)
            Text(message)
                .font(Typefaces.description)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 430)
            if let actionTitle, let action {
                ActionButton(kind: .secondary, title: actionTitle, action: action)
            }
        }
        .padding(.vertical, 44)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .card()
    }
}

// MARK: - Barra di caricamento

struct ShimmerBar: View {
    @State private var phase: CGFloat = -0.7

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Palette.accentBlue.opacity(0.85), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width)
            }
            .clipped()
        }
        .frame(height: 5)
        .onAppear {
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                phase = 1.7
            }
        }
    }
}

// MARK: - Avvisi flottanti

/// Messaggio discreto in fondo all'area di lavoro, per conferme ed errori.
struct ToastOverlay: View {
    let toast: AppState.Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.isError ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.isError ? Palette.dangerRed : Palette.successGreen)

            Text(toast.message)
                .font(Typefaces.mono(12))
                .foregroundStyle(Palette.primaryText)
                .frame(maxWidth: 480, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: 0x242429).opacity(0.88))
                .shadow(color: Color.black.opacity(0.4), radius: 22, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
