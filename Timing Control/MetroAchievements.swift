import SwiftUI

// A single achievement definition. `check` returns true when earned given the store.
struct MetroAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let check: (MetroProgressStore) -> Bool
}

enum MetroAchievements {
    // The catalog. Evaluated after every recorded result.
    static let all: [MetroAchievement] = {
        var list: [MetroAchievement] = []

        // First clear.
        list.append(MetroAchievement(
            id: "first_clear", title: "First Departure",
            detail: "Clear your first level.",
            check: { $0.levelsCleared() >= 1 }))

        // Chapter clears (clear every level in a chapter, i.e. all stars >= 1).
        for c in 0..<MetroLevels.chapterCount {
            let chapter = c
            list.append(MetroAchievement(
                id: "chapter_\(chapter)",
                title: "\(MetroLevels.chapterName(chapter)) Cleared",
                detail: "Clear every level in Chapter \(chapter + 1).",
                check: { store in
                    let range = MetroLevels.indices(inChapter: chapter)
                    return range.allSatisfy { store.starsFor($0) >= 1 }
                }))
        }

        // Total-stars milestones.
        for milestone in [10, 30, 60, 100] {
            let m = milestone
            list.append(MetroAchievement(
                id: "stars_\(m)", title: "\(m) Stars",
                detail: "Earn \(m) stars in total.",
                check: { $0.totalStars() >= m }))
        }

        // Earn 3 stars on a level.
        list.append(MetroAchievement(
            id: "perfect_one", title: "Right On Time",
            detail: "Earn 3 stars on any level.",
            check: { $0.threeStarCount() >= 1 }))

        // Beat par on K levels.
        for k in [5, 15, 30] {
            let kk = k
            list.append(MetroAchievement(
                id: "underpar_\(kk)", title: "Under Par x\(kk)",
                detail: "Beat par (3 stars) on \(kk) levels.",
                check: { $0.underParCount() >= kk }))
        }

        // No-collision clear streak.
        for streak in [5, 12] {
            let s = streak
            list.append(MetroAchievement(
                id: "streak_\(s)", title: "Clean Run x\(s)",
                detail: "Clear \(s) levels in a row without a collision.",
                check: { $0.bestNoCollisionStreak >= s }))
        }

        return list
    }()

    // Evaluate the whole catalog; unlock anything newly earned.
    static func evaluate(store: MetroProgressStore) {
        for a in all where !store.isAchievementUnlocked(a.id) {
            if a.check(store) {
                store.unlock(a.id, title: a.title)
            }
        }
    }

    static var total: Int { all.count }

    static func unlockedCount(store: MetroProgressStore) -> Int {
        all.filter { store.isAchievementUnlocked($0.id) }.count
    }
}
