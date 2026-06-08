import SwiftUI
import Combine

// A live train in the running simulation.
struct MetroTrain: Identifiable {
    let id: Int
    let lineId: Int
    let colorIndex: Int
    let label: String
    let route: [Int]          // node ids
    var routeIndex: Int = 0   // index of the node the train currently sits AT or just left
    var progress: CGFloat = 0 // 0...1 progress along the edge from route[routeIndex] -> route[routeIndex+1]
    var moving: Bool = false  // currently traversing an edge
    var held: Bool = true     // held at a station (player controlled)
    var arrived: Bool = false // reached destination
    var available: Bool = false // depart delay elapsed; can be released
    var departDelay: Double = 0

    // The node the train is sitting at (only meaningful when !moving).
    var currentNode: Int { route[routeIndex] }
    // The node the train moves toward when traversing.
    var nextNode: Int? { routeIndex + 1 < route.count ? route[routeIndex + 1] : nil }
}

enum MetroGameState: Equatable {
    case running
    case won(stars: Int, time: Double)
    case failed(reason: String)
}

final class MetroGameEngine: ObservableObject {
    @Published private(set) var trains: [MetroTrain] = []
    @Published private(set) var state: MetroGameState = .running
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var conflictEdgeId: Int? = nil   // edge currently flashing as a conflict
    @Published private(set) var occupiedSegments: Set<Int> = []  // shared edge ids currently occupied

    let level: MetroLevel
    private var timer: Timer?
    private let tick: Double = 1.0 / 30.0   // 30 fps discrete stepping

    init(level: MetroLevel) {
        self.level = level
        reset()
    }

    func reset() {
        timer?.invalidate()
        elapsed = 0
        conflictEdgeId = nil
        occupiedSegments = []
        state = .running
        trains = level.trains.map { def in
            let line = level.line(def.lineId)
            return MetroTrain(id: def.id,
                              lineId: def.lineId,
                              colorIndex: line.colorIndex,
                              label: def.label,
                              route: line.route,
                              held: true,
                              available: def.departDelay <= 0,
                              departDelay: def.departDelay)
        }
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }

    // Player taps a train at a station to toggle hold/release.
    func toggleTrain(_ id: Int) {
        guard state == .running else { return }
        guard let idx = trains.firstIndex(where: { $0.id == id }) else { return }
        var t = trains[idx]
        guard !t.arrived else { return }
        // Can only toggle when sitting at a node (not mid-edge) and available.
        guard !t.moving else { return }
        guard t.available else { return }
        // Only stations can hold trains; junctions always pass straight through, so a
        // train must never be left stranded (held) on a junction.
        guard level.node(t.currentNode).isStation else { return }
        t.held.toggle()
        trains[idx] = t
    }

    // Which edge a moving train logically occupies.
    private func occupiedEdge(of t: MetroTrain) -> MetroEdge? {
        guard t.moving, let n = t.nextNode else { return nil }
        return level.edge(between: t.currentNode, n)
    }

    private func step() {
        guard state == .running else { return }
        elapsed += tick

        // Mark trains available once their depart delay passes.
        for i in trains.indices where !trains[i].available {
            if elapsed >= trains[i].departDelay {
                trains[i].available = true
            }
        }

        // Advance moving trains; start movement for released, non-moving trains.
        let stepProgress = CGFloat(tick / max(level.segmentTravel, 0.1))

        for i in trains.indices {
            var t = trains[i]
            if t.arrived { continue }

            if t.moving {
                t.progress += stepProgress
                if t.progress >= 1.0 {
                    // Arrived at next node.
                    t.progress = 0
                    t.routeIndex += 1
                    t.moving = false
                    if t.routeIndex >= t.route.count - 1 {
                        t.arrived = true
                        t.held = false
                    } else {
                        // Auto-hold at stations; auto-continue through junctions.
                        let node = level.node(t.currentNode)
                        if node.isStation {
                            t.held = true   // require player to release again at stations
                        } else {
                            t.held = false  // junctions pass straight through
                        }
                    }
                }
                trains[i] = t
            } else if !t.held && t.available && !t.arrived {
                // Begin traversing the next edge.
                if t.nextNode != nil {
                    t.moving = true
                    trains[i] = t
                }
            }
        }

        recomputeOccupancyAndConflicts()
        checkWin()
    }

    private func recomputeOccupancyAndConflicts() {
        var occ: [Int: [Int]] = [:]   // edgeId -> [trainId]
        for t in trains where t.moving {
            if let e = occupiedEdge(of: t) {
                occ[e.id, default: []].append(t.id)
            }
        }

        var occupiedShared: Set<Int> = []
        for (edgeId, riders) in occ {
            let edge = level.edges.first(where: { $0.id == edgeId })!
            if edge.shared {
                occupiedShared.insert(edgeId)
                if riders.count > 1 {
                    // CONFLICT: two trains on same shared segment.
                    triggerConflict(on: edgeId)
                    return
                }
            }
        }
        occupiedSegments = occupiedShared

        // No active conflict this frame (a real conflict ends the run before reaching here),
        // so clear any stale highlight.
        conflictEdgeId = nil
    }

    private func triggerConflict(on edgeId: Int) {
        conflictEdgeId = edgeId
        let edge = level.edges.first(where: { $0.id == edgeId })!
        let aName = level.node(edge.a).name
        let bName = level.node(edge.b).name
        state = .failed(reason: "Two trains collided on the \(aName)–\(bName) segment.")
        stop()
    }

    private func checkWin() {
        guard state == .running else { return }
        if trains.allSatisfy({ $0.arrived }) {
            let stars = starRating(for: elapsed)
            state = .won(stars: stars, time: elapsed)
            stop()
        }
    }

    func starRating(for time: Double) -> Int {
        if time <= level.parTime { return 3 }
        if time <= level.parTime * 1.4 { return 2 }
        return 1
    }
}
