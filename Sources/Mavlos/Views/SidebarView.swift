import SwiftUI
import MavlosCore

/// Navigazione persistente dell'app: header con controlli di sistema,
/// nome del prodotto e le tre voci principali.
struct SidebarView: View {
    @EnvironmentObject private var state: AppState

    private let items: [AppState.Page] = [.home, .scan, .settings]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.leading, 12)
                .padding(.top, 8)

            navList
                .padding(.top, 28)

            Spacer()
        }
        .frame(width: 208, alignment: .topLeading)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1)
        }
    }

    private var brand: some View {
        Text("mavlos")
            .font(Typefaces.brand)
            .foregroundStyle(Palette.primaryText)
    }

    private var navList: some View {
        VStack(spacing: 6) {
            ForEach(items) { page in
                navRow(page)
            }
        }
        .padding(.horizontal, 12)
    }

    private func navRow(_ page: AppState.Page) -> some View {
        let isSelected = state.page == page

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                state.page = page
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: page.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(page.title)
                    .font(Typefaces.navItem)
                Spacer()
            }
            .foregroundStyle(isSelected ? Palette.primaryText : Palette.secondaryText.opacity(0.9))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Vetro con tinta blu della sidebar e bordo leggermente più chiaro in alto.
    private var sidebarBackground: some View {
        ZStack {
            SidebarGlassBackground()
            LinearGradient(
                colors: [
                    Palette.sidebarTint.opacity(0.78),
                    Palette.sidebarTint.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
