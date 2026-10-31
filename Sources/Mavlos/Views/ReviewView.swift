import SwiftUI
import AppKit
import QuickLookThumbnailing
import MavlosCore

/// Anteprima delle operazioni: ogni file con origine, destinazione e
/// avvisi prima di qualunque spostamento (PRD §9).
struct ReviewView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if state.reviewMode == .single {
            SingleReviewFlow()
                .environmentObject(state)
        } else {
            BatchReviewView()
                .environmentObject(state)
        }
    }
}

// MARK: - Anteprima di un file (icona rapida + QLThumbnail)

struct FileThumbView: View {
    let url: URL
    var size: CGFloat = 34

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hex: 0x25252A)))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task {
            thumbnail = await FileThumbView.thumbnail(for: url, side: size)
        }
    }

    static func thumbnail(for url: URL, side: CGFloat) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: side * 2, height: side * 2),
                scale: 2,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }
}

// MARK: - Revisione in blocco

private struct BatchReviewView: View {
    @EnvironmentObject private var state: AppState

    @State private var filter: FileCategory?
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            toolbar

            proposalList

            footer
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $state.showConfirmation) {
            ConfirmationSheet()
                .environmentObject(state)
        }
    }

    // MARK: Segments

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.s("Rivedi le operazioni"))
                    .font(Typefaces.pageTitle)
                    .foregroundStyle(Palette.primaryText)
                MonoValue(summaryLine, size: 12)
            }
            Spacer()
            MascotBadge(size: 46)
        }
    }

    private var summaryLine: String {
        let total = state.proposals.count
        let selected = state.selectedMoveCount
        let conflicts = state.proposals.filter { $0.conflict != .none }.count
        return L.formatted("%d file · %d selezionati · %d conflitti", total, selected, conflicts)
    }

    private var filteredProposals: [MoveProposal] {
        state.proposals.filter { proposal in
            let matchesCategory = filter == nil ? true : proposal.item.category == filter
            let matchesSearch = searchText.isEmpty
                ? true
                : proposal.item.displayName.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private var presentCategories: [FileCategory] {
        var counts: [FileCategory: Int] = [:]
        for proposal in state.proposals {
            counts[proposal.item.category, default: 0] += 1
        }
        return FileCategory.allCases.filter { (counts[$0] ?? 0) > 0 }
    }

    // MARK: Barra strumenti

    private var toolbar: some View {
        HStack(spacing: 10) {
            chip(for: nil)
            ForEach(presentCategories, id: \.self) { category in
                chip(for: category)
            }
            Spacer()
            TextField(L.s("Cerca file…"), text: $searchText)
                .textFieldStyle(.plain)
                .font(Typefaces.mono(12))
                .foregroundStyle(Palette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(width: 210)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func chip(for category: FileCategory?) -> some View {
        let isSelected = filter == category
        let label = category?.shortLabel ?? L.s("Tutti")
        let count = category == nil
            ? state.proposals.count
            : state.proposals.filter { $0.item.category == category }.count

        return Button(action: {
            withAnimation(.easeOut(duration: 0.14)) {
                filter = category
            }
        }) {
            HStack(spacing: 7) {
                if let category {
                    CategoryDot(color: Palette.color(for: category), size: 7)
                }
                Text(label)
                    .font(Typefaces.mono(11.5, .medium))
                Text(Formatting.fileCount(count))
                    .font(Typefaces.mono(10.5))
                    .opacity(0.55)
            }
            .foregroundStyle(isSelected ? Palette.primaryText : Palette.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.13) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Elenco

    private var proposalList: some View {
        Group {
            if filteredProposals.isEmpty {
                VStack(spacing: 8) {
                    Text(L.s("Nessun file nel filtro corrente"))
                        .font(Typefaces.small)
                        .foregroundStyle(Palette.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .card(radius: 14)
            } else {
                List(filteredProposals, id: \.id) { proposal in
                    ProposalRow(proposal: proposal)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .card(radius: 14)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if state.organizing {
                organizingBar
            } else {
                Text(L.s("nessun file viene eliminato, solo spostato"))
                    .font(Typefaces.mono(11))
                    .foregroundStyle(Palette.primaryText.opacity(0.35))

                Spacer()

                ActionButton(
                    kind: .secondary,
                    title: L.s("Torna ai risultati"),
                    action: { state.exitReview(to: .results) }
                )
                ActionButton(
                    kind: .secondary,
                    title: state.selectedMoveCount > 0
                        ? L.s("Escludi selezione")
                        : L.s("Seleziona tutto"),
                    action: {
                        if state.selectedMoveCount > 0 {
                            state.excludeSelection()
                        } else {
                            state.selectAllEligible()
                        }
                    }
                )
                ActionButton(
                    kind: .primary,
                    title: L.formatted("Sposta %d file", state.selectedMoveCount),
                    icon: "checkmark",
                    action: { state.requestOrganize() }
                )
                .opacity(state.selectedMoveCount == 0 ? 0.45 : 1)
            }
        }
    }

    /// Avanzamento organizzazione reale (nessuna percentuale inventata).
    private var organizingBar: some View {
        HStack(spacing: 14) {
            Text(L.formatted(
                "Spostati %d di %d file",
                state.organizationProgress.completed,
                state.organizationProgress.total
            ))
            .font(Typefaces.mono(12))
            .foregroundStyle(Palette.primaryText)

            ShimmerBar()
                .frame(maxWidth: 260)

            MonoValue(state.organizationProgress.currentFile ?? "—", size: 11.5)
                .frame(maxWidth: 220, alignment: .leading)
        }
    }
}

// MARK: - Riga di una proposta

private struct ProposalRow: View {
    let proposal: MoveProposal

    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { state.toggleProposal(proposal.id) }) {
                SelectionBox(checked: proposal.isSelected, size: 20)
            }
            .buttonStyle(.plain)
            .opacity(proposal.isEligible ? 1 : 0.35)
            .disabled(!proposal.isEligible)

            FileThumbView(url: proposal.item.url, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(proposal.item.displayName)
                        .font(Typefaces.sans(13.5, .medium))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if proposal.warnings.contains(.nameConflict) {
                        WarningChip(
                            text: proposal.policy == .skip
                                ? L.s("sarà saltato")
                                : L.s("sarà rinominato")
                        )
                    }
                    if proposal.warnings.contains(.unknownType) {
                        WarningChip(text: L.s("da verificare"), color: Palette.warningAmber)
                    }
                    if proposal.warnings.contains(.alreadyInPlace) {
                        WarningChip(text: L.s("già a posto"), color: Palette.successGreen)
                    }
                    if let note = proposal.note {
                        Text(note)
                            .font(Typefaces.mono(10))
                            .foregroundStyle(Palette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                MonoValue(PathDefaults.compactPath(proposal.item.url), size: 10.5)
            }
            .frame(minWidth: 260, maxWidth: 430, alignment: .leading)

            Spacer(minLength: 12)

            destinationColumn
                .frame(width: 250, alignment: .leading)

            Text(Formatting.fileSize(proposal.item.size))
                .font(Typefaces.mono(11.5))
                .foregroundStyle(Palette.secondaryText)
                .frame(width: 76, alignment: .trailing)

            rowMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            proposal.isSelected ? Color.white.opacity(0.035) : Color.clear
        )
        .contentShape(Rectangle())
        .contextMenu { menuActions }
    }

    private var destinationColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                CategoryDot(color: Palette.color(for: proposal.item.category), size: 7)
                Text(proposal.item.category.shortLabel)
                    .font(Typefaces.mono(11, .medium))
                    .foregroundStyle(Palette.primaryText.opacity(0.85))
                    .lineLimit(1)
            }
            MonoValue(
                proposal.item.destinationURL.map { PathDefaults.displayPath($0) } ?? L.s("nessuna destinazione"),
                size: 10.5
            )
        }
    }

    // MARK: Menu per file

    private var rowMenu: some View {
        Menu {
            menuActions
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .padding(7)
                .background(
                    Circle().fill(Color.white.opacity(0.05))
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L.s("Azioni sul file"))
    }

    @ViewBuilder
    private var menuActions: some View {
        Menu(L.s("Cambia categoria")) {
            ForEach(FileCategory.allCases, id: \.self) { category in
                Button(category.displayName) {
                    state.changeCategory(category, forIDs: [proposal.id])
                }
            }
        }

        Button(L.s("Scegli destinazione…")) {
            chooseAlternativeDestination()
        }

        Divider()

        Menu(L.s("Duplicati")) {
            ForEach(ConflictPolicy.allCases, id: \.self) { policy in
                Button(policy.displayName) {
                    state.setConflictPolicy(policy, forIDs: [proposal.id])
                }
            }
        }

        Button {
            state.organizeSingleNow(proposal.id)
        } label: {
            Text(L.s("Sposta solo questo file"))
        }
        .disabled(!proposal.isEligible)

        Divider()

        Button(L.s("Mostra nel Finder")) {
            NSWorkspace.shared.activateFileViewerSelecting([proposal.item.url])
        }
    }

    private func chooseAlternativeDestination() {
        Task {
            let urls = await state.chooseFolder(message: L.s("Cartella di destinazione"))
            if let url = urls.first {
                state.setDestination(url, forIDs: [proposal.id])
            }
        }
    }
}

// MARK: - Flusso "uno a uno"

private struct SingleReviewFlow: View {
    @EnvironmentObject private var state: AppState

    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.s("Rivedi le operazioni"))
                        .font(Typefaces.pageTitle)
                        .foregroundStyle(Palette.primaryText)
                    MonoValue(L.s("modalità uno a uno — confermi ogni spostamento"), size: 12)
                }
                Spacer()
                MascotBadge(size: 46)
            }

            Spacer()

            if let proposal = state.currentSingleProposal {
                SingleProposalCard(proposal: proposal, busy: $busy)
            } else {
                EmptyStateCard(
                    systemImage: "checkmark.seal",
                    title: L.s("Operazioni completate"),
                    message: L.s("Tutti i file nel flusso sono stati trattati."),
                    actionTitle: L.s("Torna ai risultati"),
                    action: { state.exitReview(to: .results) }
                )
                .frame(maxWidth: 560)
                .padding(.bottom, 30)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SingleProposalCard: View {
    let proposal: MoveProposal
    @Binding var busy: Bool

    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                MonoValue(stepLabel, size: 12)
                Spacer()
                Button(L.s("Torna ai risultati")) {
                    state.exitReview(to: .results)
                }
                .font(Typefaces.mono(11.5))
                .foregroundStyle(Palette.secondaryText)
                .buttonStyle(.plain)
                .hoverRow(cornerRadius: 8)
            }

            HStack(alignment: .top, spacing: 18) {
                FileThumbView(url: proposal.item.url, size: 72)

                VStack(alignment: .leading, spacing: 7) {
                    Text(proposal.item.displayName)
                        .font(Typefaces.sans(17, .semibold))
                        .foregroundStyle(Palette.primaryText)
                        .lineLimit(1)
                        .help(proposal.item.displayName)

                    MonoValue(Formatting.fileSize(proposal.item.size), size: 11.5)
                    MonoValue(PathDefaults.compactPath(proposal.item.url), size: 11.5)

                    if let created = proposal.item.creationDate {
                        MonoValue(L.formatted("creato %@", formatted(created)), size: 10.5)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        CategoryDot(color: Palette.color(for: proposal.item.category), size: 7)
                        Text(proposal.item.category.shortLabel)
                            .font(Typefaces.mono(12, .medium))
                            .foregroundStyle(Palette.primaryText)
                    }
                    MonoValue(
                        proposal.item.destinationURL.map { "→ " + PathDefaults.displayPath($0) } ?? "→ " + L.s("nessuna destinazione"),
                        size: 11.5
                    )

                    HStack(spacing: 10) {
                        Menu(L.s("Cambia categoria")) {
                            ForEach(FileCategory.allCases, id: \.self) { category in
                                Button(category.displayName) {
                                    state.changeCategory(category, forIDs: [proposal.id])
                                }
                            }
                        }
                        .font(Typefaces.mono(11))

                        Button(L.s("Scegli destinazione…")) {
                            Task {
                                let urls = await state.chooseFolder(message: L.s("Cartella di destinazione"))
                                if let url = urls.first {
                                    state.setDestination(url, forIDs: [proposal.id])
                                }
                            }
                        }
                        .font(Typefaces.mono(11))
                        .foregroundStyle(Palette.secondaryText)
                        .buttonStyle(.plain)
                        .hoverRow(cornerRadius: 6)
                    }

                    if !proposal.warnings.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(proposal.warnings).sorted { $0.rawValue < $1.rawValue }, id: \.self) { warning in
                                WarningChip(text: FileOrganizer.warningDescription(warning))
                            }
                        }
                    }
                }
            }

            HStack {
                ActionButton(
                    kind: .secondary,
                    title: L.s("Salta"),
                    action: { state.skipSingle() }
                )
                ActionButton(
                    kind: .primary,
                    title: L.s("Sposta questo file"),
                    icon: "checkmark",
                    action: {
                        guard proposal.isEligible else {
                            state.showToast(L.s("Nessuna destinazione valida"), isError: true)
                            return
                        }
                        busy = true
                        state.moveCurrentSingle(proposal)
                        busy = false
                    }
                )
                .opacity(proposal.isEligible ? 1 : 0.45)
            }
        }
        .padding(24)
        .card(radius: 16)
        .frame(maxWidth: 780)
    }

    private var stepLabel: String {
        let visibleEligible = state.proposals.filter { $0.isEligible }.count
        return L.formatted("File %d di %d rimanenti", state.singleIndex + 1, visibleEligible)
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Foglia di conferma (riepilogo delle modifiche)

struct ConfirmationSheet: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let pending = state.proposals.filter { $0.isSelected && $0.isEligible }
        let stats = Self.categorySummaries(pending)

        VStack(alignment: .leading, spacing: 18) {
            Text(L.formatted("Confermi lo spostamento di %d file?", pending.count))
                .font(Typefaces.sans(20, .semibold))
                .foregroundStyle(Palette.primaryText)

            VStack(spacing: 0) {
                ForEach(stats, id: \.0) { summary in
                    HStack(spacing: 10) {
                        CategoryDot(color: Palette.color(for: summary.0), size: 7)
                        Text(summary.0.shortLabel)
                            .font(Typefaces.rowTitle)
                            .foregroundStyle(Palette.primaryText)
                        Spacer()
                        MonoValue("→ \(PathDefaults.displayPath(summary.2))", size: 11.5)
                        Text(Formatting.fileCount(summary.1))
                            .font(Typefaces.mono(13, .medium))
                            .foregroundStyle(Palette.primaryText)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                    if summary.0 != stats.last?.0 {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }

            Text(L.s("Se un file omonimo esiste già in destinazione, resta intatto: Mavlos rinomina quello in arrivo o salta l'operazione."))
                .font(Typefaces.mono(11))
                .foregroundStyle(Palette.mutedText)

            HStack {
                Spacer()
                ActionButton(kind: .secondary, title: L.s("Annulla")) {
                    state.showConfirmation = false
                }
                ActionButton(kind: .primary, title: L.formatted("Sposta %d file", pending.count), icon: "checkmark") {
                    Task { await state.runOrganization() }
                }
            }
        }
        .padding(26)
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0x2A2A2F))
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private typealias Summary = (FileCategory, Int, URL)

    private static func categorySummaries(_ proposals: [MoveProposal]) -> [Summary] {
        var counts: [FileCategory: Int] = [:]
        var destinations: [FileCategory: URL] = [:]
        for proposal in proposals {
            counts[proposal.item.category, default: 0] += 1
            if let destination = proposal.item.destinationURL {
                destinations[proposal.item.category] = destination
            }
        }
        return counts
            .map { ($0.key, $0.value, destinations[$0.key] ?? URL(fileURLWithPath: "/") ) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }
}
