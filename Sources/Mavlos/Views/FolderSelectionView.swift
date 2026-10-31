import SwiftUI
import AppKit
import MavlosCore

/// "Cosa vuoi scansionare?" — selezione multipla delle cartelle
/// (riferimento: screenshot 4).
struct FolderSelectionView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            folderCard
                .frame(maxWidth: 760, alignment: .leading)

            privacyNote

            Spacer()

            footerActions
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.s("Cosa vuoi scansionare?"))
                    .font(Typefaces.pageTitle)
                    .foregroundStyle(Palette.primaryText)
                Text(L.s("Puoi sceglierne più d'una."))
                    .font(Typefaces.bodyText)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()
            MascotBadge(size: 46)
        }
    }

    // MARK: - Card cartelle

    private var folderCard: some View {
        VStack(spacing: 0) {
            ForEach(state.folderOptions) { ref in
                FolderRow(
                    ref: ref,
                    checked: state.selectedFolderIDs.contains(ref.id),
                    isDefault: isDefault(ref)
                )
                if ref.id != state.folderOptions.last?.id {
                    rowSeparator
                }
            }
            rowSeparator
            otherFolderRow
        }
        .card(radius: 16)
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }

    private func isDefault(_ ref: FolderRef) -> Bool {
        state.defaultFolderRef?.url.standardizedFileURL.path == ref.url.standardizedFileURL.path
    }

    private var otherFolderRow: some View {
        Button(action: {
            Task {
                let urls = await state.chooseFolder(message: L.s("Scegli una cartella nel Finder"))
                if !urls.isEmpty {
                    state.addCustomFolder(from: urls)
                }
            }
        }) {
            HStack(spacing: 14) {
                SelectionBox(checked: false, size: 0)
                    .opacity(0)
                    .frame(width: 21, height: 21)
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.s("Altra cartella…"))
                        .font(Typefaces.rowTitle)
                        .foregroundStyle(Palette.primaryText)
                    MonoValue(L.s("scegli dal Finder"), size: 11.5)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverRow(cornerRadius: 0)
    }

    // MARK: - Nota privacy

    private var privacyNote: some View {
        Text(L.s("Mavlos legge nomi, tipologie e dimensioni dei file per proporti dove spostarli. Nessun dato lascia il tuo Mac."))
            .font(Typefaces.mono(11))
            .foregroundStyle(Palette.mutedText)
            .frame(maxWidth: 560, alignment: .leading)
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack {
            Spacer()
            ActionButton(
                kind: .secondary,
                title: L.s("Annulla"),
                action: { state.cancelFolderSelection() }
            )
            ActionButton(
                kind: .primary,
                title: scanButtonLabel,
                icon: "viewfinder",
                action: { state.startScanForSelection() }
            )
            .opacity(state.selectedFolderRefs.isEmpty ? 0.45 : 1)
        }
    }

    private var scanButtonLabel: String {
        let count = state.selectedFolderRefs.count
        if count == 0 { return L.s("Scansiona 0 cartelle") }
        return count == 1
            ? L.formatted("Scansiona %d cartella", 1)
            : L.formatted("Scansiona %d cartelle", count)
    }
}

/// Riga di una cartella selezionabile.
private struct FolderRow: View {
    let ref: FolderRef
    let checked: Bool
    let isDefault: Bool

    @EnvironmentObject private var state: AppState
    @State private var accessibility: FolderAccessibility = .accessible

    var body: some View {
        Button(action: { state.toggleFolder(ref) }) {
            HStack(spacing: 14) {
                SelectionBox(checked: checked)

                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(ref.displayName)
                            .font(Typefaces.rowTitle)
                            .foregroundStyle(Palette.primaryText)
                        if isDefault {
                            WarningChip(text: L.s("predefinita"), color: Palette.accentBlue)
                        }
                        if accessibility != .accessible {
                            WarningChip(
                                text: accessibility == .missing
                                    ? L.s("cartella inesistente")
                                    : L.s("permessi necessari"),
                                color: Palette.warningAmber
                            )
                        }
                    }
                    MonoValue(PathDefaults.displayPath(ref.url), size: 11.5)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverRow(cornerRadius: 0)
        .onAppear {
            accessibility = PermissionManager.accessibility(of: ref.url)
        }
    }
}
