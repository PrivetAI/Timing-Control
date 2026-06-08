import SwiftUI

// The app shell: a CUSTOM tab bar (HStack of Buttons with custom Shape icons) over
// a switch on the selected tab. NOT a TabView, no NavigationStack. The in-level
// GameView overlay lives inside the Play tab (PlayView) and, while a level is open,
// the tab bar hides so the game is full-screen.
struct RootMenuView: View {
    enum Tab: Int, CaseIterable { case play, themes, awards, more }

    @State private var tab: Tab = .play
    @State private var inLevel = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MetroTheme.background.ignoresSafeArea()

            // Tab content.
            Group {
                switch tab {
                case .play:   PlayView(inLevel: $inLevel)
                case .themes: ThemesView()
                case .awards: AwardsView()
                case .more:   MoreView()
                }
            }
            // Leave room for the tab bar except in-level (full screen).
            .padding(.bottom, inLevel ? 0 : tabBarHeight)

            if !inLevel {
                tabBar
            }
        }
    }

    private let tabBarHeight: CGFloat = 62

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.play, "Play")
            tabButton(.themes, "Themes")
            tabButton(.awards, "Awards")
            tabButton(.more, "More")
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            MetroTheme.panel
                .shadow(color: MetroTheme.shadow, radius: 6, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ t: Tab, _ label: String) -> some View {
        let active = tab == t
        let color = active ? MetroTheme.primary : MetroTheme.inkSoft
        return Button(action: { tab = t }) {
            VStack(spacing: 4) {
                tabIcon(t, color: color)
                    .frame(width: 26, height: 26)
                Text(label)
                    .font(.system(size: 11, weight: active ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func tabIcon(_ t: Tab, color: Color) -> some View {
        switch t {
        case .play:   MetroPlayTabIcon(size: 26, color: color)
        case .themes: MetroThemeIcon(size: 26, color: color)
        case .awards: MetroAwardTabIcon(size: 26, color: color)
        case .more:   MetroMoreTabIcon(size: 26, color: color)
        }
    }
}
