import SwiftUI

// Persists level unlocking, best star ratings and best times in UserDefaults.
// All NEW state (achievements, stats, selected skin) is stored under
// NEW keys and defaults safely — the original stars/times/highest keys and
// formats are left untouched so old saves load without loss.
final class MetroProgressStore: ObservableObject {
    static let shared = MetroProgressStore()

    // --- Original keys (DO NOT CHANGE format) ---
    private let starsKey = "metro_dispatch_stars_v1"
    private let timesKey = "metro_dispatch_besttimes_v1"
    private let highestKey = "metro_dispatch_highest_unlocked_v1"

    // --- New additive keys ---
    private let achievementsKey = "metro_dispatch_achievements_v1"
    private let skinKey = "metro_dispatch_selected_skin_v1"
    private let noCollisionStreakKey = "metro_dispatch_streak_v1"
    private let bestStreakKey = "metro_dispatch_best_streak_v1"

    // index -> best stars earned (0 if never cleared)
    @Published private(set) var stars: [Int: Int] = [:]
    // index -> best (lowest) time
    @Published private(set) var bestTimes: [Int: Double] = [:]
    // highest unlocked level index (always at least 0)
    @Published private(set) var highestUnlocked: Int = 0

    // New: unlocked achievement ids.
    @Published private(set) var unlockedAchievements: Set<String> = []
    // New: selected cosmetic skin id.
    @Published var selectedSkinId: String = "classic" {
        didSet {
            if oldValue != selectedSkinId {
                defaults.set(selectedSkinId, forKey: skinKey)
            }
        }
    }
    // New: current consecutive no-collision clear streak + best ever.
    @Published private(set) var noCollisionStreak: Int = 0
    @Published private(set) var bestNoCollisionStreak: Int = 0

    // A transient banner string for a freshly unlocked achievement (UI toast).
    @Published var recentlyUnlocked: String? = nil

    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    private func load() {
        if let dict = defaults.dictionary(forKey: starsKey) as? [String: Int] {
            for (k, v) in dict { if let i = Int(k) { stars[i] = v } }
        }
        if let dict = defaults.dictionary(forKey: timesKey) as? [String: Double] {
            for (k, v) in dict { if let i = Int(k) { bestTimes[i] = v } }
        }
        highestUnlocked = defaults.integer(forKey: highestKey)

        if let arr = defaults.array(forKey: achievementsKey) as? [String] {
            unlockedAchievements = Set(arr)
        }
        if let s = defaults.string(forKey: skinKey) { selectedSkinId = s }
        noCollisionStreak = defaults.integer(forKey: noCollisionStreakKey)
        bestNoCollisionStreak = defaults.integer(forKey: bestStreakKey)
    }

    private func persist() {
        var sDict: [String: Int] = [:]
        for (k, v) in stars { sDict[String(k)] = v }
        defaults.set(sDict, forKey: starsKey)

        var tDict: [String: Double] = [:]
        for (k, v) in bestTimes { tDict[String(k)] = v }
        defaults.set(tDict, forKey: timesKey)

        defaults.set(highestUnlocked, forKey: highestKey)
    }

    private func persistExtras() {
        defaults.set(Array(unlockedAchievements), forKey: achievementsKey)
        defaults.set(noCollisionStreak, forKey: noCollisionStreakKey)
        defaults.set(bestNoCollisionStreak, forKey: bestStreakKey)
    }

    // MARK: Queries

    func isUnlocked(_ index: Int) -> Bool { index <= highestUnlocked }

    func starsFor(_ index: Int) -> Int { stars[index] ?? 0 }
    func bestTimeFor(_ index: Int) -> Double? { bestTimes[index] }

    func totalStars() -> Int { stars.values.reduce(0, +) }

    // Count of distinct levels cleared (1+ star).
    func levelsCleared() -> Int { stars.values.filter { $0 >= 1 }.count }
    // Count of levels with 3 stars.
    func threeStarCount() -> Int { stars.values.filter { $0 >= 3 }.count }

    // Number of levels beaten under par (== 3 stars under this rating model).
    func underParCount() -> Int { threeStarCount() }

    // MARK: Recording level results

    func recordResult(level index: Int, stars newStars: Int, time: Double, totalLevels: Int) {
        let prev = stars[index] ?? 0
        if newStars > prev { stars[index] = newStars }
        if let bt = bestTimes[index] {
            if time < bt { bestTimes[index] = time }
        } else {
            bestTimes[index] = time
        }
        if newStars >= 1 {
            let next = min(index + 1, totalLevels - 1)
            if next > highestUnlocked { highestUnlocked = next }
            // No-collision win advances the streak.
            noCollisionStreak += 1
            if noCollisionStreak > bestNoCollisionStreak {
                bestNoCollisionStreak = noCollisionStreak
            }
        }
        persist()
        persistExtras()
        MetroAchievements.evaluate(store: self)
    }

    // A failed (collision) run resets the no-collision streak.
    func recordCollision() {
        if noCollisionStreak != 0 {
            noCollisionStreak = 0
            persistExtras()
        }
    }

    // MARK: Achievements

    func unlock(_ id: String, title: String) {
        guard !unlockedAchievements.contains(id) else { return }
        unlockedAchievements.insert(id)
        recentlyUnlocked = title
        persistExtras()
    }

    func isAchievementUnlocked(_ id: String) -> Bool {
        unlockedAchievements.contains(id)
    }

    // MARK: Reset

    func resetAll() {
        stars = [:]
        bestTimes = [:]
        highestUnlocked = 0
        unlockedAchievements = []
        noCollisionStreak = 0
        bestNoCollisionStreak = 0
        selectedSkinId = "classic"
        persist()
        persistExtras()
    }
}
