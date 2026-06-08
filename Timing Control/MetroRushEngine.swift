import SwiftUI

// Endless "Rush" dispatcher engine. A sibling of MetroGameEngine that reuses the
// SAME discrete 30fps stepping model and the SAME MetroTrain struct, but instead
// of a fixed roster of trains, new trains SPAWN over time on a compact FIXED map.
//
// The player holds/releases trains to avoid collisions on shared segments. A
// collision ends the run. Score = trains delivered. Spawn frequency rises as the
// score grows. Concurrent trains are capped for fairness/perf, and a train only
// spawns at a HOLDABLE origin station that is currently free, so the player always
// has reaction time (the train starts held).
final class MetroRushEngine: ObservableObject {
    enum Phase: Equatable { case idle, running, over }

    @Published private(set) var trains: [MetroTrain] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var score: Int = 0          // delivered trains
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var conflictEdgeId: Int? = nil
    @Published private(set) var occupiedSegments: Set<Int> = []

    let level: MetroLevel       // the fixed Rush map (geometry + lines)
    private var timer: Timer?
    private let tick: Double = 1.0 / 30.0
    private var nextTrainId = 0
    private var spawnTimer: Double = 0
    private var rng = SystemRandomNumberGenerator()
    private let maxConcurrent = 6

    init() {
        self.level = MetroRushMap.make()
    }

    deinit { timer?.invalidate() }

    func startRun() {
        timer?.invalidate()
        trains = []
        score = 0
        elapsed = 0
        conflictEdgeId = nil
        occupiedSegments = []
        nextTrainId = 0
        spawnTimer = 0
        phase = .running
        spawnTrain()   // first train immediately (held)
        timer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func toggleTrain(_ id: Int) {
        guard phase == .running else { return }
        guard let idx = trains.firstIndex(where: { $0.id == id }) else { return }
        var t = trains[idx]
        guard !t.arrived, !t.moving, t.available else { return }
        guard level.node(t.currentNode).isStation else { return }
        t.held.toggle()
        trains[idx] = t
    }

    // Current spawn interval (seconds) — shortens as score climbs, floored for fairness.
    private var spawnInterval: Double {
        max(1.6, 4.2 - Double(score) * 0.12)
    }

    private func step() {
        guard phase == .running else { return }
        elapsed += tick
        spawnTimer += tick

        // Spawn logic.
        if spawnTimer >= spawnInterval, activeCount < maxConcurrent {
            spawnTimer = 0
            spawnTrain()
        }

        let stepProgress = CGFloat(tick / max(level.segmentTravel, 0.1))
        var delivered = 0

        for i in trains.indices {
            var t = trains[i]
            if t.arrived { continue }
            if t.moving {
                t.progress += stepProgress
                if t.progress >= 1.0 {
                    t.progress = 0
                    t.routeIndex += 1
                    t.moving = false
                    if t.routeIndex >= t.route.count - 1 {
                        t.arrived = true
                        t.held = false
                        delivered += 1
                    } else {
                        let node = level.node(t.currentNode)
                        t.held = node.isStation
                    }
                }
                trains[i] = t
            } else if !t.held && t.available && !t.arrived {
                if t.nextNode != nil { t.moving = true; trains[i] = t }
            }
        }

        if delivered > 0 { score += delivered }

        // Remove arrived trains from the board so it stays compact.
        trains.removeAll { $0.arrived }

        recomputeOccupancyAndConflicts()
    }

    private var activeCount: Int { trains.filter { !$0.arrived }.count }

    private func spawnTrain() {
        // Pick a free origin station and a different destination station, then a
        // line/route that goes from origin toward destination. Our Rush map is a
        // star hub: every station routes through the central hub to another station.
        let stations = level.nodes.filter { $0.isStation }
        guard stations.count >= 2 else { return }

        // Origins that are currently free (no held/sitting train there) so the new
        // train can sit there and the player has time to react.
        let occupiedOrigins = Set(trains.filter { !$0.moving && !$0.arrived }.map { $0.currentNode })
        let freeStations = stations.filter { !occupiedOrigins.contains($0.id) }
        guard let origin = freeStations.randomElement(using: &rng) else { return }

        let dests = stations.filter { $0.id != origin.id }
        guard let dest = dests.randomElement(using: &rng) else { return }

        // Build a route origin -> hub -> dest using the map's hub node.
        guard let route = MetroRushMap.route(from: origin.id, to: dest.id, in: level) else { return }

        let colorIndex = nextTrainId % MetroTheme.lineColors.count
        let label = "\(["R", "B", "G", "P", "O"][colorIndex % 5])\(nextTrainId + 1)"
        var t = MetroTrain(id: nextTrainId,
                           lineId: 0,
                           colorIndex: colorIndex,
                           label: label,
                           route: route,
                           held: true,
                           available: true,
                           departDelay: 0)
        t.routeIndex = 0
        trains.append(t)
        nextTrainId += 1
    }

    private func occupiedEdge(of t: MetroTrain) -> MetroEdge? {
        guard t.moving, let n = t.nextNode else { return nil }
        return level.edge(between: t.currentNode, n)
    }

    private func recomputeOccupancyAndConflicts() {
        var occ: [Int: [Int]] = [:]
        for t in trains where t.moving {
            if let e = occupiedEdge(of: t) { occ[e.id, default: []].append(t.id) }
        }
        var occupiedShared: Set<Int> = []
        for (edgeId, riders) in occ {
            guard let edge = level.edges.first(where: { $0.id == edgeId }) else { continue }
            if edge.shared {
                occupiedShared.insert(edgeId)
                if riders.count > 1 {
                    conflictEdgeId = edgeId
                    endRun()
                    return
                }
            }
        }
        occupiedSegments = occupiedShared
        conflictEdgeId = nil
    }

    private func endRun() {
        phase = .over
        stop()
        MetroProgressStore.shared.recordRush(score: score)
    }
}

// The fixed Rush map: a compact central hub with radial stations. Every spoke into
// the hub is a SHARED segment, so any two trains crossing the hub at once collide.
// This gives a clean, readable endless puzzle.
enum MetroRushMap {
    static let hubId = 0
    static let armCount = 5

    static func make() -> MetroLevel {
        var nodes: [MetroNode] = [
            MetroNode(id: hubId, x: 0.5, y: 0.5, name: "Central", isStation: false)
        ]
        var edges: [MetroEdge] = []
        for i in 0..<armCount {
            let ang = (Double(i) / Double(armCount)) * 2 * Double.pi - Double.pi / 2
            let x = 0.5 + CGFloat(cos(ang)) * 0.40
            let y = 0.5 + CGFloat(sin(ang)) * 0.40
            let id = i + 1
            nodes.append(MetroNode(id: id, x: x, y: y, name: "P\(i + 1)", isStation: true))
            edges.append(MetroEdge(id: i, a: id, b: hubId, shared: true))
        }
        // A single placeholder line so MetroLevel is well-formed; Rush builds routes
        // dynamically per spawned train.
        let line = MetroLineDef(id: 0, colorIndex: 0, route: [1, hubId, 2])
        return MetroLevel(id: 9000, name: "Rush Hub", nodes: nodes, edges: edges,
                          lines: [line], trains: [], parTime: 0, segmentTravel: 1.5)
    }

    // Route any station to any other station through the hub.
    static func route(from a: Int, to b: Int, in level: MetroLevel) -> [Int]? {
        guard a != b, a != hubId, b != hubId else { return nil }
        // Validity: both spokes must exist.
        guard level.edge(between: a, hubId) != nil, level.edge(between: hubId, b) != nil else { return nil }
        return [a, hubId, b]
    }
}
