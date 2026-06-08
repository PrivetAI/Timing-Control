import SwiftUI

// Awards tab: a Stats panel + the achievements catalog (locked/unlocked).
struct AwardsView: View {
    @ObservedObject private var progress = MetroProgressStore.shared

    private var chaptersCleared: Int {
        (0..<MetroLevels.chapterCount).filter { c in
            MetroLevels.indices(inChapter: c).allSatisfy { progress.starsFor($0) >= 1 }
        }.count
    }

    var body: some View {
        ZStack {
            MetroTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 14) {
                        statsCard
                        Text("ACHIEVEMENTS  (\(MetroAchievements.unlockedCount(store: progress)) / \(MetroAchievements.total))")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        ForEach(MetroAchievements.all) { a in
                            achievementRow(a)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            MetroAwardTabIcon(size: 30, color: MetroTheme.gold)
            Text("Awards")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.ink)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR RECORD")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.inkSoft)
            statRow("Levels cleared", "\(progress.levelsCleared()) / \(MetroLevels.totalLevels)")
            statRow("Total stars", "\(progress.totalStars()) / \(MetroLevels.totalLevels * 3)")
            statRow("3-star levels", "\(progress.threeStarCount())")
            statRow("Chapters cleared", "\(chaptersCleared) / \(MetroLevels.chapterCount)")
            statRow("Best clean streak", "\(progress.bestNoCollisionStreak)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.cardBackground)
            .shadow(color: MetroTheme.shadow, radius: 3, y: 1))
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(MetroTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.primary)
        }
    }

    private func achievementRow(_ a: MetroAchievement) -> some View {
        let unlocked = progress.isAchievementUnlocked(a.id)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(unlocked ? MetroTheme.gold.opacity(0.18) : MetroTheme.trackBase.opacity(0.4))
                    .frame(width: 44, height: 44)
                if unlocked {
                    MetroStarIcon(size: 22, filled: true)
                } else {
                    MetroLockIcon(size: 20, color: MetroTheme.inkSoft)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(a.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(unlocked ? MetroTheme.ink : MetroTheme.inkSoft)
                Text(a.detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.cardBackground)
            .shadow(color: MetroTheme.shadow, radius: 2, y: 1))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(unlocked ? MetroTheme.gold.opacity(0.5) : Color.clear, lineWidth: 1.5))
        .opacity(unlocked ? 1 : 0.85)
    }
}
