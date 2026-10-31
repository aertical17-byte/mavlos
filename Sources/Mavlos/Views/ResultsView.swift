import SwiftUI
import MavlosCore

/// Riepilogo delle categorie ricavate dalla scansione reale
/// (riferimento: screenshot 3).
struct ResultsView: View {
    @EnvironmentObject private var state: AppState
    @State private var animateBars = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let result = state.scanResult {
                if result.totalCount == 0 {
                    emptyState(result)
                } else {
                    header(for: result)
                    categoryCard(for: result)
                    if !result.failureNotes.isEmpty {
                        notesCard(for: result)
                    }
                    runSummary
                    Spacer()
                }
                footerActions(result: result)
            } else {
                noResultsState
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            animateBars = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                animateBars = true
            }
        }
    }

    // MARK: - Header

    private func header(for result: ScanResult) -> some View {
        HStack(alignment: .top, spacing: 14) {
            MascotBadge(size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(L.formatted("%d file trovati", result.totalCount))
                    .font(Typefaces.resultsTitle)
                    .foregroundStyle(Palette.primaryText)
                MonoValue(subtitle(for: result), size: 12)
            }
            Spacer()
        }
    }

    private func subtitle(for result: ScanResult) -> String {
        let folders = result.folders.map { PathDefaults.displayPath($0.url) }.joined(separator: " · ")
        let stateLabel = result.wasCancelled ? L.s("scansione annullata") : L.s("scansione completata")
        return "\(folders) · \(stateLabel)"
    }

    // MARK: - Card categorie

    private func categoryCard(for result: ScanResult) -> some View {
        let stats = result.categoryStats()
        let total = max(result.totalCount, 1)

        return VStack(spacing: 0) {
            ForEach(stats) { stat in
                CategoryStatRow(
                    stat: stat,
                    fraction: CGFloat(Double(stat.count) / Double(total)),
                    animated: animateBars
                )
                if stat.id != stats.last?.id {
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 1)
                }
            }
        }
        .card(radius: 16)
        .frame(maxWidth: 980, alignment: .leading)
    }

    private struct CategoryStatRow: View {
        let stat: CategoryStats
        let fraction: CGFloat
        let animated: Bool

        var body: some View {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    CategoryDot(color: Palette.color(for: stat.category))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.category.shortLabel)
                            .font(Typefaces.rowTitle)
                            .foregroundStyle(Palette.primaryText)
                        MonoValue(
                            stat.destination.map { "→ \(PathDefaults.displayPath($0))" } ?? "→ —",
                            size: 11.5
                        )
                    }
                }
                .frame(minWidth: 220, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.09))
                        Capsule()
                            .fill(Palette.color(for: stat.category))
                            .frame(width: max(6, geometry.size.width * (animated ? fraction : 0)))
                    }
                }
                .frame(height: 5)
                .frame(maxWidth: 280)

                Spacer(minLength: 12)

                Text(Formatting.fileCount(stat.count))
                    .font(Typefaces.mono(13, .medium))
                    .foregroundStyle(Palette.primaryText)
                    .frame(width: 52, alignment: .trailing)
                    .monospacedDigit()

                Text(Formatting.fileSize(stat.size))
                    .font(Typefaces.mono(11.5))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(minWidth: 74, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Note (cartelle non accessibili ecc.)

    private func notesCard(for result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(result.failureNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.warningAmber)
                        .padding(.top, 1)
                    Text(note)
                        .font(Typefaces.mono(11.5))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 980, alignment: .leading)
        .card(radius: 12, fill: Palette.cardFill.opacity(0.8))
    }

    // MARK: - Riepilogo organizzazione completata

    @ViewBuilder
    private var runSummary: some View {
        if let run = state.organizationRun {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: run.failedCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(run.failedCount == 0 ? Palette.successGreen : Palette.warningAmber)
                    Text(L.s("Organizzazione") + " · " + run.stateDescription)
                        .font(Typefaces.sectionTitle)
                        .foregroundStyle(Palette.primaryText)
                    Spacer()
                    ActionButton(
                        kind: .secondary,
                        title: L.s("Annulla ultima operazione"),
                        action: { state.undoLastOperation() }
                    )
                    ActionButton(
                        kind: .primary,
                        title: L.s("Fatto"),
                        action: { state.completeReview() }
                    )
                }
                Text(L.formatted(
                    "Spostati %d file · Saltati %d · Non riusciti %d",
                    run.movedCount, run.skippedCount, run.failedCount
                ))
                .font(Typefaces.mono(12))
                .foregroundStyle(Palette.secondaryText)
            }
            .padding(20)
            .card(radius: 14)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    // MARK: - Stati vuoti

    @ViewBuilder
    private func emptyState(_ result: ScanResult) -> some View {
        Spacer()
        EmptyStateCard(
            systemImage: "tray",
            title: L.s("Nessun file da organizzare"),
            message: result.wasCancelled
                ? L.s("La scansione è stata annullata prima di leggere alcun file.")
                : L.s("La cartella non contiene file da sistemare.")
        )
        .frame(maxWidth: 620)
        Spacer()
        footerActions(result: result)
    }

    @ViewBuilder
    private var noResultsState: some View {
        Spacer()
        EmptyStateCard(
            systemImage: "square.grid.2x2",
            title: L.s("Nessun risultato"),
            message: L.s("Avvia una scansione per visualizzare i file della cartella."),
            actionTitle: L.s("Nuova scansione"),
            action: { state.openFolderSelection(from: .home) }
        )
        .frame(maxWidth: 620)
        Spacer()
    }

    // MARK: - Footer

    private func footerActions(result: ScanResult) -> some View {
        HStack {
            Text(L.s("nessun file viene eliminato, solo spostato"))
                .font(Typefaces.mono(11))
                .foregroundStyle(Palette.primaryText.opacity(0.35))
            Spacer()
            if result.totalCount > 0 {
                ActionButton(
                    kind: .secondary,
                    title: L.s("Uno a uno"),
                    action: { state.beginReview(mode: .single) }
                )
                ActionButton(
                    kind: .primary,
                    title: L.s("Metti in ordine"),
                    icon: "checkmark",
                    action: { state.beginReview(mode: .batch) }
                )
            }
        }
    }
}
