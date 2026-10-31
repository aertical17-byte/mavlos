import SwiftUI
import MavlosCore

/// Finestra principale: sidebar fissa a sinistra + area di lavoro che
/// cambia con la navigazione e con le fasi dello scan flow.
struct MainView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            workArea
        }
        .background(AmbientBackground())
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) { toastLayer }
    }

    @ViewBuilder
    private var workArea: some View {
        ZStack(alignment: .topTrailing) {
            switch state.page {
            case .home:
                HomeView()
            case .scan:
                scanFlow
            case .settings:
                SettingsView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.page)
        .animation(.easeInOut(duration: 0.2), value: state.scanStage)
    }

    @ViewBuilder
    private var scanFlow: some View {
        switch state.scanStage {
        case .folderSelection:
            FolderSelectionView()
        case .progress:
            ScanProgressView()
        case .results:
            ResultsView()
        case .review:
            ReviewView()
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = state.toast {
            ToastOverlay(toast: toast)
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
