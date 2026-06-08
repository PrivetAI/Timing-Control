import SwiftUI

// The Play tab: a chaptered level select. Chapters are collapsible sections; each
// holds a grid of level cards (locked / unlocked, stars, best time). Tapping an
// unlocked level pushes the GameView overlay (kept inside this tab, no NavigationStack).
struct PlayView: View {
    // Bound to the parent so the tab bar can hide while a level is open.
    @Binding var inLevel: Bool
    @ObservedObject private var progress = MetroProgressStore.shared
    @State private var selectedLevel: Int? = nil
    @State private var expandedChapter: Int

    private func openLevel(_ i: Int) {
        withAnimation(.easeInOut(duration: 0.2)) { selectedLevel = i }
        inLevel = true
    }
    private func closeLevel() {
        withAnimation(.easeInOut(duration: 0.2)) { selectedLevel = nil }
        inLevel = false
    }

    init(inLevel: Binding<Bool>) {
        _inLevel = inLevel
        // Default-expand the chapter containing the player's current frontier.
        let frontier = MetroProgressStore.shared.highestUnlocked
        _expandedChapter = State(initialValue: MetroLevels.chapter(of: frontier))
    }

    var body: some View {
        ZStack {
            MetroTheme.background.ignoresSafeArea()
            if let lvl = selectedLevel {
                GameView(levelIndex: lvl, onExit: { closeLevel() })
                .transition(.opacity)
            } else {
                menuContent
            }
        }
    }

    private var menuContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                MetroTrainIcon(size: 36, color: MetroTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timing Control")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundColor(MetroTheme.ink)
                    HStack(spacing: 5) {
                        MetroStarIcon(size: 13, filled: true)
                        Text("\(progress.totalStars()) / \(MetroLevels.totalLevels * 3) stars")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<MetroLevels.chapterCount, id: \.self) { chapter in
                        chapterSection(chapter)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func chapterSection(_ chapter: Int) -> some View {
        let indices = MetroLevels.indices(inChapter: chapter)
        let chapterStars = indices.reduce(0) { $0 + progress.starsFor($1) }
        let unlockedInChapter = indices.contains { progress.isUnlocked($0) }
        let isExpanded = expandedChapter == chapter

        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedChapter = isExpanded ? -1 : chapter
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((unlockedInChapter ? MetroTheme.primary : MetroTheme.inkSoft).opacity(0.15))
                            .frame(width: 38, height: 38)
                        if unlockedInChapter {
                            Text("\(chapter + 1)")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundColor(MetroTheme.primary)
                        } else {
                            MetroLockIcon(size: 18, color: MetroTheme.inkSoft)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MetroLevels.chapterName(chapter))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(unlockedInChapter ? MetroTheme.ink : MetroTheme.inkSoft)
                        Text("\(chapterStars) / \(indices.count * 3) stars")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                    }
                    Spacer()
                    MetroBackIcon(size: 16, color: MetroTheme.inkSoft)
                        .rotationEffect(.degrees(isExpanded ? -90 : 180))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.cardBackground)
                    .shadow(color: MetroTheme.shadow, radius: 2, y: 1))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(indices, id: \.self) { i in
                        levelCard(index: i)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 2)
            }
        }
    }

    private func levelCard(index: Int) -> some View {
        let level = MetroLevels.get(index)
        let unlocked = progress.isUnlocked(index)
        let stars = progress.starsFor(index)
        let lineColor = MetroTheme.lineColors[index % MetroTheme.lineColors.count]

        return Button(action: {
            if unlocked { openLevel(index) }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle().fill(lineColor.opacity(0.18)).frame(width: 38, height: 38)
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(lineColor)
                    }
                    Spacer()
                    if !unlocked { MetroLockIcon(size: 20, color: MetroTheme.inkSoft) }
                }
                Text(level.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(unlocked ? MetroTheme.ink : MetroTheme.inkSoft)
                    .lineLimit(1)
                Text("\(level.lines.count) lines · \(level.trains.count) trains")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { s in
                        MetroStarIcon(size: 14, filled: s < stars)
                    }
                    Spacer()
                    if let bt = progress.bestTimeFor(index) {
                        Text(String(format: "%.1fs", bt))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(MetroTheme.primary)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(MetroTheme.cardBackground)
                .shadow(color: MetroTheme.shadow, radius: 4, y: 2))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(lineColor.opacity(unlocked ? 0.4 : 0.12), lineWidth: 1.5))
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!unlocked)
    }
}
