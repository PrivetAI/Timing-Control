import SwiftUI

// Deterministic, seeded procedural level generator.
//
// Produces clean, valid, solvable maps for every global index beyond the six
// hand-authored intro levels (Chapter 1). A given index ALWAYS yields the same
// MetroLevel (the seed is derived from the index), and MetroLevels caches the
// result so we never regenerate.
//
// Validity guarantees (verified by construction + a final self-check):
//   * Every line route uses only node ids that exist.
//   * Every consecutive pair in a route has a connecting edge.
//   * Every line's FIRST and LAST route node is a station (isStation == true);
//     interior nodes may be junctions.
// Solvability is guaranteed by serialization: all trains start held at their
// origin stations and the player can release them one at a time. As long as the
// graph/routes are valid and origins/destinations are stations, the level is
// always clearable. Par only affects the star rating, never solvability.
enum MetroLevelGenerator {

    // A tiny deterministic PRNG (SplitMix64) so generation is reproducible and
    // does not depend on the system RNG.
    private struct SeededRNG {
        var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func int(_ range: Range<Int>) -> Int {
            let span = UInt64(range.count)
            return range.lowerBound + Int(next() % span)
        }
        mutating func double() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func bool(_ p: Double) -> Bool { double() < p }
    }

    // The available structured archetypes. Each lays out nodes on a clean,
    // intentional grid/geometry in normalized [0,1] coords (never random scatter).
    private enum Archetype: Int, CaseIterable {
        case crossHub        // central hub, 4 radial station arms
        case sharedSpine     // one shared corridor, lines branch on/off
        case ringSpokes      // central ring of junctions with station spokes
        case twinSpines      // two parallel spines + crossovers
        case starHub         // central hub with N radial stations
        case smallGrid       // 3x3 grid of nodes, lines run rows/cols
    }

    // Public entry. globalIndex is the absolute level index (>= handAuthored count).
    static func generate(globalIndex: Int) -> MetroLevel {
        let chapter = MetroLevels.chapter(of: globalIndex)
        let inChapter = globalIndex % MetroLevels.levelsPerChapter
        var rng = SeededRNG(seed: UInt64(globalIndex) &* 0x100000001B3 &+ 0xABCDEF)

        // Difficulty scales with chapter (0-based). Chapter 1 is hand-authored, so
        // generated content starts at chapter index 1.
        let difficulty = chapter   // 1..8 for generated chapters

        // Pick an archetype deterministically from (chapter, inChapter).
        let all = Archetype.allCases
        let pick = (chapter * 7 + inChapter * 3) % all.count
        let archetype = all[pick]

        let built: BuiltLevel
        switch archetype {
        case .crossHub:    built = buildCrossHub(difficulty: difficulty, rng: &rng)
        case .sharedSpine: built = buildSharedSpine(difficulty: difficulty, rng: &rng)
        case .ringSpokes:  built = buildRingSpokes(difficulty: difficulty, rng: &rng)
        case .twinSpines:  built = buildTwinSpines(difficulty: difficulty, rng: &rng)
        case .starHub:     built = buildStarHub(difficulty: difficulty, rng: &rng)
        case .smallGrid:   built = buildSmallGrid(difficulty: difficulty, rng: &rng)
        }

        // Trains: one per line plus a few extra on busy lines, with a staggered
        // depart-delay spread that widens with difficulty.
        let trains = buildTrains(lines: built.lines, difficulty: difficulty, rng: &rng)

        // Segment travel time: slightly faster (tighter) in later chapters.
        let segTravel = max(1.2, 1.7 - Double(difficulty) * 0.05)

        // Par: generous estimate. Longest single route time + buffer per extra train.
        let longestRoute = built.lines.map { $0.route.count - 1 }.max() ?? 1
        let extraTrains = max(0, trains.count - built.lines.count)
        let basePar = Double(longestRoute) * segTravel
        let buffer = Double(trains.count) * segTravel * 1.6 + Double(extraTrains) * segTravel
        // Tighten par a little each chapter (smaller multiplier later) but keep generous.
        let parSlack = max(1.5, 2.4 - Double(difficulty) * 0.08)
        let par = (basePar + buffer) * parSlack * 0.5

        let level = MetroLevel(
            id: globalIndex,
            name: generatedName(chapter: chapter, inChapter: inChapter, archetype: archetype),
            nodes: built.nodes,
            edges: built.edges,
            lines: built.lines,
            trains: trains,
            parTime: (par).rounded(),
            segmentTravel: segTravel
        )

        // Final self-check (debug builds): assert validity invariants. In release
        // this is a no-op; construction already guarantees correctness.
        assert(validate(level), "Generated level \(globalIndex) failed validity self-check")
        return level
    }

    // MARK: - Built scaffold

    private struct BuiltLevel {
        var nodes: [MetroNode]
        var edges: [MetroEdge]
        var lines: [MetroLineDef]
    }

    // Helper that accumulates nodes/edges and dedupes edges by node pair so route
    // adjacencies always have exactly one edge.
    private final class Builder {
        var nodes: [MetroNode] = []
        var edges: [MetroEdge] = []
        private var edgeKey: [String: Int] = [:]   // "a-b" sorted -> edge id

        func addNode(_ id: Int, _ x: CGFloat, _ y: CGFloat, _ name: String, station: Bool) {
            nodes.append(MetroNode(id: id, x: clamp01(x), y: clamp01(y), name: name, isStation: station))
        }

        // Ensure an edge exists between a and b; returns its id. shared can be
        // upgraded (if any caller marks the pair shared, it stays shared).
        @discardableResult
        func connect(_ a: Int, _ b: Int, shared: Bool) -> Int {
            let key = a < b ? "\(a)-\(b)" : "\(b)-\(a)"
            if let id = edgeKey[key] {
                if shared, let idx = edges.firstIndex(where: { $0.id == id }), !edges[idx].shared {
                    edges[idx] = MetroEdge(id: id, a: edges[idx].a, b: edges[idx].b, shared: true)
                }
                return id
            }
            let id = edges.count
            edges.append(MetroEdge(id: id, a: a, b: b, shared: shared))
            edgeKey[key] = id
            return id
        }
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0.05), 0.95) }

    // Build edges to cover every adjacency in a route, then register the line.
    private static func makeLine(_ id: Int, colorIndex: Int, route: [Int],
                                 sharedPairs: Set<String>, builder: Builder) -> MetroLineDef {
        for i in 0..<(route.count - 1) {
            let a = route[i], b = route[i + 1]
            let key = a < b ? "\(a)-\(b)" : "\(b)-\(a)"
            builder.connect(a, b, shared: sharedPairs.contains(key))
        }
        return MetroLineDef(id: id, colorIndex: colorIndex, route: route)
    }

    private static func pairKey(_ a: Int, _ b: Int) -> String { a < b ? "\(a)-\(b)" : "\(b)-\(a)" }

    // MARK: - Archetypes
    //
    // Each archetype returns a BuiltLevel. Routes always START and END at stations.
    // The shared (critical) segments are the crux of the puzzle.

    // Cross hub: a central junction with 4 station arms. Lines cross through the hub.
    private static func buildCrossHub(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        // hub
        b.addNode(0, 0.5, 0.5, "Central", station: false)
        // four arm endpoints (stations)
        b.addNode(1, 0.5, 0.10, "North", station: true)
        b.addNode(2, 0.90, 0.5, "East", station: true)
        b.addNode(3, 0.5, 0.90, "South", station: true)
        b.addNode(4, 0.10, 0.5, "West", station: true)
        // optional mid junctions on arms for longer routes in harder chapters
        let longArms = difficulty >= 3
        if longArms {
            b.addNode(5, 0.5, 0.30, "N-Jn", station: false)
            b.addNode(6, 0.70, 0.5, "E-Jn", station: false)
            b.addNode(7, 0.5, 0.70, "S-Jn", station: false)
            b.addNode(8, 0.30, 0.5, "W-Jn", station: false)
        }

        // An arm from a station endpoint to (but not including) the hub.
        func armStub(_ end: Int, _ mid: Int) -> [Int] { longArms ? [end, mid] : [end] }
        // A full route that runs station -> hub -> station (hub appears exactly once).
        func crossRoute(_ a: Int, _ am: Int, _ c: Int, _ cm: Int) -> [Int] {
            armStub(a, am) + [0] + armStub(c, cm).reversed()
        }

        // Shared: the spokes into the hub are the conflict points.
        var sharedPairs = Set<String>()
        // N-S line and E-W line both cross hub -> mark hub-adjacent edges shared.
        let nRoute = crossRoute(1, 5, 3, 7)   // N -> hub -> S
        let eRoute = crossRoute(2, 6, 4, 8)   // E -> hub -> W
        for r in [nRoute, eRoute] {
            for i in 0..<(r.count - 1) { sharedPairs.insert(pairKey(r[i], r[i + 1])) }
        }

        var lines: [MetroLineDef] = []
        lines.append(makeLine(0, colorIndex: 0, route: nRoute, sharedPairs: sharedPairs, builder: b))
        lines.append(makeLine(1, colorIndex: 1, route: eRoute, sharedPairs: sharedPairs, builder: b))
        // A third diagonal line in harder chapters (N -> hub -> E).
        if difficulty >= 4 {
            let dRoute = crossRoute(1, 5, 2, 6)
            for i in 0..<(dRoute.count - 1) { sharedPairs.insert(pairKey(dRoute[i], dRoute[i + 1])) }
            lines.append(makeLine(2, colorIndex: 2, route: dRoute, sharedPairs: sharedPairs, builder: b))
        }
        // rebuild edges' shared flags now that sharedPairs may have grown:
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    // Shared spine: a horizontal corridor of junctions; lines enter from station
    // stubs, ride a stretch of the shared spine, then exit to another station.
    private static func buildSharedSpine(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        let spineLen = min(3 + difficulty / 2, 5)   // number of spine junctions
        var spine: [Int] = []
        for i in 0..<spineLen {
            let t = CGFloat(i) / CGFloat(max(spineLen - 1, 1))
            let id = i
            b.addNode(id, 0.15 + t * 0.70, 0.5, "S\(i)", station: false)
            spine.append(id)
        }
        // Station stubs above and below each end + middle.
        var nextId = spineLen
        func stub(at spineIdx: Int, above: Bool, name: String) -> Int {
            let sx = b.nodes[spineIdx].x
            let id = nextId; nextId += 1
            b.addNode(id, sx, above ? 0.18 : 0.82, name, station: true)
            return id
        }
        let topLeft = stub(at: 0, above: true, name: "North A")
        let botLeft = stub(at: 0, above: false, name: "South A")
        let topRight = stub(at: spineLen - 1, above: true, name: "North B")
        let botRight = stub(at: spineLen - 1, above: false, name: "South B")

        // The whole spine is shared.
        var sharedPairs = Set<String>()
        for i in 0..<(spine.count - 1) { sharedPairs.insert(pairKey(spine[i], spine[i + 1])) }

        var lines: [MetroLineDef] = []
        // Line 0: topLeft -> spine -> botRight
        let r0 = [topLeft] + spine + [botRight]
        lines.append(makeLine(0, colorIndex: 0, route: r0, sharedPairs: sharedPairs, builder: b))
        // Line 1: botLeft -> spine -> topRight
        let r1 = [botLeft] + spine + [topRight]
        lines.append(makeLine(1, colorIndex: 2, route: r1, sharedPairs: sharedPairs, builder: b))
        // Extra mid line in harder chapters: middle stub down -> spine right portion.
        if difficulty >= 3 && spineLen >= 3 {
            let midIdx = spineLen / 2
            let midStub = stub(at: midIdx, above: true, name: "Mid")
            let r2 = [midStub] + Array(spine[midIdx...]) + [botRight]
            lines.append(makeLine(2, colorIndex: 1, route: r2, sharedPairs: sharedPairs, builder: b))
        }
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    // Ring with spokes: a central ring of 4 junctions; each has an outward station
    // spoke. Lines run spoke -> ring arc -> spoke. The ring arcs are shared.
    private static func buildRingSpokes(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        // ring junctions (N,E,S,W) around center
        let cx: CGFloat = 0.5, cy: CGFloat = 0.5, r: CGFloat = 0.20
        b.addNode(0, cx, cy - r, "RingN", station: false)
        b.addNode(1, cx + r, cy, "RingE", station: false)
        b.addNode(2, cx, cy + r, "RingS", station: false)
        b.addNode(3, cx - r, cy, "RingW", station: false)
        // station spokes
        b.addNode(4, cx, 0.08, "North End", station: true)
        b.addNode(5, 0.92, cy, "East End", station: true)
        b.addNode(6, cx, 0.92, "South End", station: true)
        b.addNode(7, 0.08, cy, "West End", station: true)

        let ring = [0, 1, 2, 3]
        var sharedPairs = Set<String>()
        for i in 0..<ring.count {
            let a = ring[i], c = ring[(i + 1) % ring.count]
            sharedPairs.insert(pairKey(a, c))
            b.connect(a, c, shared: true)
        }
        // spoke connections (not shared)
        b.connect(4, 0, shared: false)
        b.connect(5, 1, shared: false)
        b.connect(6, 2, shared: false)
        b.connect(7, 3, shared: false)

        var lines: [MetroLineDef] = []
        // Each line: station -> ringJn -> nextRingJn -> station (one arc).
        let arcs = [(4, 0, 1, 5), (5, 1, 2, 6), (6, 2, 3, 7), (7, 3, 0, 4)]
        let lineCount = min(2 + difficulty / 2, 4)
        for li in 0..<lineCount {
            let (sa, ja, jb, sb) = arcs[li]
            let route = [sa, ja, jb, sb]
            lines.append(makeLine(li, colorIndex: li % 5, route: route, sharedPairs: sharedPairs, builder: b))
        }
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    // Twin parallel spines with crossovers connecting them.
    private static func buildTwinSpines(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        let cols = min(3 + difficulty / 3, 4)
        // top spine ids 0..cols-1, bottom spine ids cols..2cols-1
        var top: [Int] = [], bot: [Int] = []
        for i in 0..<cols {
            let t = CGFloat(i) / CGFloat(max(cols - 1, 1))
            let x = 0.12 + t * 0.66
            let topId = i
            let isEnd = (i == 0 || i == cols - 1)
            b.addNode(topId, x, 0.28, "T\(i)", station: isEnd)
            top.append(topId)
            let botId = cols + i
            b.addNode(botId, x, 0.72, "B\(i)", station: isEnd)
            bot.append(botId)
        }
        // a right hub station
        let hub = 2 * cols
        b.addNode(hub, 0.92, 0.5, "Hub", station: true)

        var sharedPairs = Set<String>()
        // all consecutive spine segments shared
        for i in 0..<(cols - 1) {
            sharedPairs.insert(pairKey(top[i], top[i + 1]))
            sharedPairs.insert(pairKey(bot[i], bot[i + 1]))
        }
        // crossovers (shared)
        b.connect(top[0], bot[0], shared: false)   // left link (not shared, gives slack)
        let crossA = top[cols / 2], crossB = bot[cols / 2]
        sharedPairs.insert(pairKey(crossA, crossB))
        b.connect(crossA, crossB, shared: true)
        // hub links
        b.connect(top[cols - 1], hub, shared: false)
        b.connect(bot[cols - 1], hub, shared: false)

        var lines: [MetroLineDef] = []
        // Line 0: top-left -> top spine -> hub
        let r0 = Array(top) + [hub]
        lines.append(makeLine(0, colorIndex: 0, route: r0, sharedPairs: sharedPairs, builder: b))
        // Line 1: bot-left -> bot spine -> hub
        let r1 = Array(bot) + [hub]
        lines.append(makeLine(1, colorIndex: 1, route: r1, sharedPairs: sharedPairs, builder: b))
        // Line 2 (crossover): top-left -> ... -> cross -> bottom spine -> hub
        if difficulty >= 3 {
            let half = cols / 2
            var r2 = Array(top[0...half])
            r2.append(bot[half])
            r2 += Array(bot[(half + 1)...]) + [hub]
            lines.append(makeLine(2, colorIndex: 3, route: r2, sharedPairs: sharedPairs, builder: b))
        }
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    // Star hub: a central hub junction with N radial stations; lines connect pairs
    // of stations through the hub. All hub spokes are shared.
    private static func buildStarHub(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        b.addNode(0, 0.5, 0.5, "Core", station: false)
        let arms = min(4 + difficulty / 2, 6)
        var stationIds: [Int] = []
        for i in 0..<arms {
            let ang = (Double(i) / Double(arms)) * 2 * Double.pi - Double.pi / 2
            let x = 0.5 + CGFloat(cos(ang)) * 0.40
            let y = 0.5 + CGFloat(sin(ang)) * 0.40
            let id = i + 1
            b.addNode(id, x, y, "P\(i + 1)", station: true)
            stationIds.append(id)
            b.connect(id, 0, shared: true)
        }
        var sharedPairs = Set<String>()
        for s in stationIds { sharedPairs.insert(pairKey(s, 0)) }

        var lines: [MetroLineDef] = []
        // Pair opposite-ish stations through the hub.
        let pairCount = min(2 + difficulty / 2, arms / 2 + 1)
        for li in 0..<pairCount {
            let aIdx = li % arms
            let bIdx = (aIdx + arms / 2) % arms
            let route = [stationIds[aIdx], 0, stationIds[bIdx]]
            lines.append(makeLine(li, colorIndex: li % 5, route: route, sharedPairs: sharedPairs, builder: b))
        }
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    // Small grid: a 3x3 lattice; corner/edge nodes are stations, center is junction.
    // Lines run across rows and columns; the central cross edges are shared.
    private static func buildSmallGrid(difficulty: Int, rng: inout SeededRNG) -> BuiltLevel {
        let b = Builder()
        // ids = r*3 + c
        for r in 0..<3 {
            for c in 0..<3 {
                let id = r * 3 + c
                let x = 0.15 + CGFloat(c) * 0.35
                let y = 0.15 + CGFloat(r) * 0.35
                // center (1,1) is a junction; everything else a station
                let isCenter = (r == 1 && c == 1)
                b.addNode(id, x, y, gridName(r, c), station: !isCenter)
            }
        }
        // connect horizontally and vertically through the grid
        var sharedPairs = Set<String>()
        for r in 0..<3 {
            for c in 0..<3 {
                let id = r * 3 + c
                if c < 2 { b.connect(id, id + 1, shared: false) }
                if r < 2 { b.connect(id, id + 3, shared: false) }
            }
        }
        // Mark the four edges touching the center (id 4) as shared.
        for n in [1, 3, 5, 7] { sharedPairs.insert(pairKey(4, n)); b.connect(4, n, shared: true) }

        var lines: [MetroLineDef] = []
        // Middle row line: 3 -> 4 -> 5
        lines.append(makeLine(0, colorIndex: 0, route: [3, 4, 5], sharedPairs: sharedPairs, builder: b))
        // Middle col line: 1 -> 4 -> 7
        lines.append(makeLine(1, colorIndex: 1, route: [1, 4, 7], sharedPairs: sharedPairs, builder: b))
        if difficulty >= 3 {
            // diagonal-ish via center: 0 -> 1 -> 4 -> 7 -> 8
            lines.append(makeLine(2, colorIndex: 2, route: [0, 1, 4, 7, 8], sharedPairs: sharedPairs, builder: b))
        }
        if difficulty >= 5 {
            lines.append(makeLine(3, colorIndex: 3, route: [2, 5, 4, 3, 6], sharedPairs: sharedPairs, builder: b))
        }
        reapplyShared(builder: b, sharedPairs: sharedPairs)
        return BuiltLevel(nodes: b.nodes, edges: b.edges, lines: lines)
    }

    private static func gridName(_ r: Int, _ c: Int) -> String {
        let cols = ["West", "Mid", "East"]
        let rows = ["North", "Central", "South"]
        if r == 1 && c == 1 { return "Interchange" }
        return "\(rows[r]) \(cols[c])"
    }

    // MARK: - Shared flag reconciliation
    //
    // Some archetypes accumulate sharedPairs after edges were first created with
    // shared:false. Re-apply the final shared set across all edges.
    private static func reapplyShared(builder b: Builder, sharedPairs: Set<String>) {
        for i in b.edges.indices {
            let e = b.edges[i]
            let key = pairKey(e.a, e.b)
            let shouldShare = sharedPairs.contains(key)
            if shouldShare != e.shared {
                b.edges[i] = MetroEdge(id: e.id, a: e.a, b: e.b, shared: shouldShare)
            }
        }
    }

    // MARK: - Trains

    private static func buildTrains(lines: [MetroLineDef], difficulty: Int, rng: inout SeededRNG) -> [MetroTrainDef] {
        var trains: [MetroTrainDef] = []
        var tid = 0
        let labels = ["R", "B", "G", "P", "O", "T"]
        let delaySpread = Double(difficulty) * 0.7   // wider stagger later
        for (li, line) in lines.enumerated() {
            let baseLabel = labels[line.colorIndex % labels.count]
            // first train on the line
            let d0 = Double(li) * (0.5 + delaySpread * 0.3)
            trains.append(MetroTrainDef(id: tid, lineId: line.id,
                                        departDelay: (d0 * 10).rounded() / 10,
                                        label: "\(baseLabel)1"))
            tid += 1
        }
        // A few extra trains on early lines in harder chapters (capped for fairness).
        let extras = min(difficulty / 2, max(0, lines.count - 1))
        for e in 0..<extras {
            let line = lines[e % lines.count]
            let baseLabel = labels[line.colorIndex % labels.count]
            let d = (Double(lines.count) * 0.6 + Double(e) * (1.0 + delaySpread * 0.2))
            trains.append(MetroTrainDef(id: tid, lineId: line.id,
                                        departDelay: (d * 10).rounded() / 10,
                                        label: "\(baseLabel)2"))
            tid += 1
        }
        return trains
    }

    // MARK: - Naming

    private static func generatedName(chapter: Int, inChapter: Int, archetype: Archetype) -> String {
        let base: String
        switch archetype {
        case .crossHub:    base = "Crossing"
        case .sharedSpine: base = "Corridor"
        case .ringSpokes:  base = "Ring Run"
        case .twinSpines:  base = "Twin Spine"
        case .starHub:     base = "Star Hub"
        case .smallGrid:   base = "Grid Lock"
        }
        return "\(base) \(chapter + 1)-\(inChapter + 1)"
    }

    // MARK: - Validation (self-check)

    static func validate(_ level: MetroLevel) -> Bool {
        let ids = Set(level.nodes.map { $0.id })
        for line in level.lines {
            guard let first = line.route.first, let last = line.route.last else { return false }
            // endpoints must be stations
            guard let fn = level.nodes.first(where: { $0.id == first }), fn.isStation else { return false }
            guard let ln = level.nodes.first(where: { $0.id == last }), ln.isStation else { return false }
            // all route ids exist + each adjacency has an edge
            for i in 0..<(line.route.count - 1) {
                let a = line.route[i], b = line.route[i + 1]
                if !ids.contains(a) || !ids.contains(b) { return false }
                if level.edge(between: a, b) == nil { return false }
            }
        }
        // every train references an existing line
        for t in level.trains where !level.lines.contains(where: { $0.id == t.lineId }) { return false }
        return true
    }
}
