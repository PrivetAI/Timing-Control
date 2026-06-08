import SwiftUI

// Persists level unlocking, best star ratings and best times in UserDefaults.
final class MetroProgressStore: ObservableObject {
    static let shared = MetroProgressStore()

    private let starsKey = "metro_dispatch_stars_v1"
    private let timesKey = "metro_dispatch_besttimes_v1"
    private let highestKey = "metro_dispatch_highest_unlocked_v1"

    // index -> best stars earned (0 if never cleared)
    @Published private(set) var stars: [Int: Int] = [:]
    // index -> best (lowest) time
    @Published private(set) var bestTimes: [Int: Double] = [:]
    // highest unlocked level index (always at least 0)
    @Published private(set) var highestUnlocked: Int = 0

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

    func isUnlocked(_ index: Int) -> Bool { index <= highestUnlocked }

    func starsFor(_ index: Int) -> Int { stars[index] ?? 0 }
    func bestTimeFor(_ index: Int) -> Double? { bestTimes[index] }

    func totalStars() -> Int { stars.values.reduce(0, +) }

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
        }
        persist()
    }

    func resetAll() {
        stars = [:]
        bestTimes = [:]
        highestUnlocked = 0
        persist()
    }
}
