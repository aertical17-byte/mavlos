import SwiftUI
import MavlosCore

/// Schermata Home: mascotte + percorso della cartella predefinita,
/// call-to-action e legenda delle categorie (riferimento: screenshot 1).
struct HomeView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 64) {
                mascotPanel
                descriptionColumn
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            scheduledBanner
                .offset(y: 90)
        }
        .padding(.horizontal, 58)
        .padding(.vertical, 40)
    }

    // MARK: Mascotte

    private var mascotPanel: some View {
        MascotBadge(size: 252, cornerRadius: 28)
            .padding(.trailing, 8)
            .padding(.top, 6)
    }

    // MARK: Testo e azioni

    private var descriptionColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            pathLine
            titleBlock
            Text(L.s("Mavlos scansiona la cartella e propone dove spostare ogni file. Tu confermi."))
                .font(Typefaces.description)
                .foregroundStyle(Palette.secondaryText)
                .frame(maxWidth: 380, alignment: .leading)
                .padding(.top, 2)

            buttonsRow
                .padding(.top, 6)
            legendRows
                .padding(.top, 4)
        }
        .padding(.top, 18)
    }

    private var pathLine: some View {
        MonoValue(
            state.defaultManifestPath,
            size: 12,
            color: Palette.primaryText.opacity(0.55)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L.s("Metti in ordine"))
                .font(Typefaces.heroTitle)
                .foregroundStyle(Palette.primaryText)
            Text(L.s("i tuoi file."))
                .font(Typefaces.heroTitle)
                .foregroundStyle(Palette.primaryText)
        }
    }

    private var buttonsRow: some View {
        HStack(spacing: 12) {
            ActionButton(
                kind: .primary,
                title: L.s("Scansiona"),
                icon: "viewfinder",
                action: { state.scanDefaultFolder() }
            )
            ActionButton(
                kind: .secondary,
                title: L.s("Altra cartella"),
                action: {
                    Task {
                        let urls = await state.chooseFolder(message: L.s("Scegli la cartella da scansionare"))
                        if !urls.isEmpty {
                            state.setAnotherHomeFolder(urls)
                        }
                    }
                }
            )
        }
    }

    private var legendRows: some View {
        HStack(spacing: 14) {
            ForEach([FileCategory.images, .documents, .music, .video], id: \.self) { category in
                HStack(spacing: 6) {
                    CategoryDot(color: Palette.color(for: category), size: 7)
                    Text(category.shortLabel.lowercased())
                        .font(Typefaces.mono(11))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    // MARK: Banner scansione pianificata

    @ViewBuilder
    private var scheduledBanner: some View {
        if let pending = state.pendingScheduledResult {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accentBlue)

                Text(L.formatted(
                    "Scansione pianificata: %d file trovati in %@",
                    pending.totalCount,
                    pending.folders.map(\.displayName).joined(separator: " · ")
                ))
                .font(Typefaces.mono(12))
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)

                Spacer()

                Button(action: state.adoptScheduledResult) {
                    Text(L.s("Rivedi"))
                        .font(Typefaces.mono(12, .semibold))
                        .foregroundStyle(Palette.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button(action: state.dismissScheduledResult) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0x22262C).opacity(0.82))
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
