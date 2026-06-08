import SwiftUI

struct RootMenuView: View {
    @ObservedObject private var progress = MetroProgressStore.shared
    @State private var selectedLevel: Int? = nil
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MetroTheme.background.ignoresSafeArea()

                if let lvl = selectedLevel {
                    GameView(levelIndex: lvl, onExit: { selectedLevel = nil })
                        .transition(.opacity)
                } else {
                    menuContent(geo: geo)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }

    private func menuContent(geo: GeometryProxy) -> some View {
        let isWide = geo.size.width > geo.size.height
        let columns = isWide ? 3 : 2
        return VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                MetroTrainIcon(size: 38, color: MetroTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timing Control")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(MetroTheme.ink)
                    HStack(spacing: 5) {
                        MetroStarIcon(size: 14, filled: true)
                        Text("\(progress.totalStars()) / \(MetroLevels.all.count * 3) stars")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                    }
                }
                Spacer()
                Button(action: { showSettings = true }) {
                    MetroSettingsIcon(size: 24, color: MetroTheme.primary)
                        .padding(10)
                        .background(Circle().fill(MetroTheme.cardBackground))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Text("SELECT A LINE")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            ScrollView {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 14), count: columns)
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(0..<MetroLevels.all.count, id: \.self) { i in
                        levelCard(index: i)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private func levelCard(index: Int) -> some View {
        let level = MetroLevels.all[index]
        let unlocked = progress.isUnlocked(index)
        let stars = progress.starsFor(index)
        let lineColor = MetroTheme.lineColors[index % MetroTheme.lineColors.count]

        return Button(action: {
            if unlocked { withAnimation(.easeInOut(duration: 0.2)) { selectedLevel = index } }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(lineColor.opacity(0.18)).frame(width: 40, height: 40)
                        Text("\(index + 1)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(lineColor)
                    }
                    Spacer()
                    if !unlocked {
                        MetroLockIcon(size: 22, color: MetroTheme.inkSoft)
                    }
                }
                Text(level.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(unlocked ? MetroTheme.ink : MetroTheme.inkSoft)
                    .lineLimit(1)
                Text("\(level.lines.count) lines · \(level.trains.count) trains")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { s in
                        MetroStarIcon(size: 16, filled: s < stars)
                    }
                    Spacer()
                    if let bt = progress.bestTimeFor(index) {
                        Text(String(format: "%.1fs", bt))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(MetroTheme.primary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(MetroTheme.cardBackground)
                    .shadow(color: MetroTheme.shadow, radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(lineColor.opacity(unlocked ? 0.4 : 0.12), lineWidth: 1.5)
            )
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!unlocked)
    }
}
