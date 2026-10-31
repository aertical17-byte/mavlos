import SwiftUI
import MavlosCore

/// Avanzamento reale della scansione: contatori dal filesystem, cartella
/// corrente e annullamento (nessuna percentuale inventata).
struct ScanProgressView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                HStack(spacing: 14) {
                    MascotBadge(size: 46)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L.s("Analisi in corso…"))
                            .font(Typefaces.pageTitle)
                            .foregroundStyle(Palette.primaryText)
                        MonoValue(progressSubtitle, size: 12)
                    }
                }
                Spacer()
            }

            CounterAndCancelCard()

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var progressSubtitle: String {
        let folders = state.scanResult?.folders
            ?? state.selectedFolderRefs
        let folderNames = folders.map { PathDefaults.displayPath($0.url) }.joined(separator: " · ")
        let folderName = folderNames.isEmpty ? "—" : folderNames
        return "\(folderName) · \(L.s("scansione in corso"))"
    }
}

/// Card con contatori aggiornati dal motore di scansione.
private struct CounterAndCancelCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 34) {
                counterLabel(tone: L.s("file analizzati"), value: state.progress.found)
                counterLabel(tone: L.s("classificati"), value: state.progress.classified)
                if state.progress.currentFolder != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.s("cartella corrente"))
                            .font(Typefaces.mono(10))
                            .kerning(0.6)
                            .foregroundStyle(Palette.primaryText.opacity(0.42))
                        MonoValue(state.progress.currentFolder ?? "—", size: 12.5)
                    }
                }
                Spacer()
            }

            ShimmerBar()

            HStack {
                Spacer()
                ActionButton(
                    kind: .secondary,
                    title: L.s("Annulla scansione"),
                    action: { state.cancelScan() }
                )
                .opacity(state.isScanning ? 1 : 0.4)
                .disabled(!state.isScanning)
            }
        }
        .padding(26)
        .frame(maxWidth: 640, alignment: .leading)
        .card(radius: 16)
        .padding(.top, 4)
    }

    private func counterLabel(tone: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tone)
                .font(Typefaces.mono(10))
                .kerning(0.6)
                .foregroundStyle(Palette.primaryText.opacity(0.42))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Formatting.fileCount(value ?? 0))
                    .font(Typefaces.statNumber)
                    .foregroundStyle(Palette.primaryText)
                    .monospacedDigit()
            }
        }
    }
}
