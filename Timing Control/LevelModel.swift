import SwiftUI

// A station node positioned in normalized [0,1] coordinates so the map scales to any area.
struct MetroNode: Identifiable {
    let id: Int
    let x: CGFloat   // 0...1
    let y: CGFloat   // 0...1
    let name: String
    let isStation: Bool   // true = a station where trains can be held; false = junction
}

// An edge (track segment) connecting two nodes. Edges are bidirectional in geometry,
// but a train traverses them in the direction dictated by its route order.
struct MetroEdge: Identifiable, Hashable {
    let id: Int
    let a: Int   // node id
    let b: Int   // node id
    let shared: Bool   // a shared/critical segment (only one train allowed at a time)
}

// A line definition: an ordered list of node ids forming the route, plus a colour index.
struct MetroLineDef: Identifiable {
    let id: Int
    let colorIndex: Int
    let route: [Int]   // ordered node ids
}

// A train spawn definition for a level.
struct MetroTrainDef: Identifiable {
    let id: Int
    let lineId: Int
    let departDelay: Double   // seconds before this train becomes available to release
    let label: String
}

// Full level definition.
struct MetroLevel: Identifiable {
    let id: Int
    let name: String
    let nodes: [MetroNode]
    let edges: [MetroEdge]
    let lines: [MetroLineDef]
    let trains: [MetroTrainDef]
    let parTime: Double        // target completion time (seconds) for 3 stars
    let segmentTravel: Double  // seconds to traverse one edge

    func node(_ id: Int) -> MetroNode { nodes.first(where: { $0.id == id })! }
    func line(_ id: Int) -> MetroLineDef { lines.first(where: { $0.id == id })! }

    // Find the edge connecting two adjacent nodes (order independent).
    func edge(between a: Int, _ b: Int) -> MetroEdge? {
        edges.first(where: { ($0.a == a && $0.b == b) || ($0.a == b && $0.b == a) })
    }
}

// All level definitions, increasing in complexity.
enum MetroLevels {
    static let all: [MetroLevel] = [
        level1(), level2(), level3(), level4(), level5(), level6()
    ]

    static func get(_ index: Int) -> MetroLevel {
        all[min(max(index, 0), all.count - 1)]
    }

    // ---- Level 1: two lines crossing at a single shared segment ----
    private static func level1() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.12, y: 0.30, name: "Ashford", isStation: true),
            MetroNode(id: 1, x: 0.40, y: 0.40, name: "Junction", isStation: false),
            MetroNode(id: 2, x: 0.60, y: 0.50, name: "Center", isStation: false),
            MetroNode(id: 3, x: 0.88, y: 0.60, name: "Bayview", isStation: true),
            MetroNode(id: 4, x: 0.18, y: 0.78, name: "Cobb", isStation: true),
            MetroNode(id: 5, x: 0.84, y: 0.20, name: "Dorset", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: false),
            MetroEdge(id: 1, a: 1, b: 2, shared: true),   // shared center segment
            MetroEdge(id: 2, a: 2, b: 3, shared: false),
            MetroEdge(id: 3, a: 4, b: 1, shared: false),
            MetroEdge(id: 4, a: 2, b: 5, shared: false)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [0, 1, 2, 3]),
            MetroLineDef(id: 1, colorIndex: 1, route: [4, 1, 2, 5])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 0, label: "B1")
        ]
        return MetroLevel(id: 0, name: "First Crossing", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 16, segmentTravel: 1.6)
    }

    // ---- Level 2: shared corridor of two segments, two trains each line ----
    private static func level2() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.10, y: 0.25, name: "Aldgate", isStation: true),
            MetroNode(id: 1, x: 0.32, y: 0.40, name: "West Jn", isStation: false),
            MetroNode(id: 2, x: 0.50, y: 0.50, name: "Mid", isStation: false),
            MetroNode(id: 3, x: 0.68, y: 0.60, name: "East Jn", isStation: false),
            MetroNode(id: 4, x: 0.90, y: 0.74, name: "Quay", isStation: true),
            MetroNode(id: 5, x: 0.12, y: 0.72, name: "Holloway", isStation: true),
            MetroNode(id: 6, x: 0.90, y: 0.26, name: "Crest", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: false),
            MetroEdge(id: 1, a: 5, b: 1, shared: false),
            MetroEdge(id: 2, a: 1, b: 2, shared: true),
            MetroEdge(id: 3, a: 2, b: 3, shared: true),
            MetroEdge(id: 4, a: 3, b: 4, shared: false),
            MetroEdge(id: 5, a: 3, b: 6, shared: false)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [0, 1, 2, 3, 4]),
            MetroLineDef(id: 1, colorIndex: 2, route: [5, 1, 2, 3, 6])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 0, label: "G1"),
            MetroTrainDef(id: 2, lineId: 0, departDelay: 3, label: "R2"),
            MetroTrainDef(id: 3, lineId: 1, departDelay: 3, label: "G2")
        ]
        return MetroLevel(id: 1, name: "Shared Corridor", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 30, segmentTravel: 1.5)
    }

    // ---- Level 3: three lines, X junction ----
    private static func level3() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.10, y: 0.20, name: "North", isStation: true),
            MetroNode(id: 1, x: 0.50, y: 0.50, name: "Grand", isStation: false),
            MetroNode(id: 2, x: 0.90, y: 0.80, name: "South", isStation: true),
            MetroNode(id: 3, x: 0.90, y: 0.20, name: "East", isStation: true),
            MetroNode(id: 4, x: 0.10, y: 0.80, name: "West", isStation: true),
            MetroNode(id: 5, x: 0.50, y: 0.12, name: "Top", isStation: true),
            MetroNode(id: 6, x: 0.50, y: 0.88, name: "Bottom", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: true),
            MetroEdge(id: 1, a: 1, b: 2, shared: true),
            MetroEdge(id: 2, a: 3, b: 1, shared: true),
            MetroEdge(id: 3, a: 1, b: 4, shared: true),
            MetroEdge(id: 4, a: 5, b: 1, shared: true),
            MetroEdge(id: 5, a: 1, b: 6, shared: true)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [0, 1, 2]),
            MetroLineDef(id: 1, colorIndex: 1, route: [3, 1, 4]),
            MetroLineDef(id: 2, colorIndex: 2, route: [5, 1, 6])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 0, label: "B1"),
            MetroTrainDef(id: 2, lineId: 2, departDelay: 0, label: "G1")
        ]
        return MetroLevel(id: 2, name: "Grand Junction", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 22, segmentTravel: 1.7)
    }

    // ---- Level 4: two parallel shared spines ----
    private static func level4() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.08, y: 0.30, name: "Alpha", isStation: true),
            MetroNode(id: 1, x: 0.30, y: 0.30, name: "J-A", isStation: false),
            MetroNode(id: 2, x: 0.55, y: 0.30, name: "J-B", isStation: false),
            MetroNode(id: 3, x: 0.80, y: 0.30, name: "Beta", isStation: true),
            MetroNode(id: 4, x: 0.08, y: 0.70, name: "Gamma", isStation: true),
            MetroNode(id: 5, x: 0.30, y: 0.70, name: "J-C", isStation: false),
            MetroNode(id: 6, x: 0.55, y: 0.70, name: "J-D", isStation: false),
            MetroNode(id: 7, x: 0.80, y: 0.70, name: "Delta", isStation: true),
            MetroNode(id: 8, x: 0.92, y: 0.50, name: "Hub", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: false),
            MetroEdge(id: 1, a: 1, b: 2, shared: true),
            MetroEdge(id: 2, a: 2, b: 3, shared: false),
            MetroEdge(id: 3, a: 4, b: 5, shared: false),
            MetroEdge(id: 4, a: 5, b: 6, shared: true),
            MetroEdge(id: 5, a: 6, b: 7, shared: false),
            MetroEdge(id: 6, a: 1, b: 5, shared: true),    // crossover
            MetroEdge(id: 7, a: 2, b: 6, shared: true),    // crossover
            MetroEdge(id: 8, a: 3, b: 8, shared: false),
            MetroEdge(id: 9, a: 7, b: 8, shared: false)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [0, 1, 2, 3]),
            MetroLineDef(id: 1, colorIndex: 1, route: [4, 5, 6, 7]),
            MetroLineDef(id: 2, colorIndex: 3, route: [0, 1, 5, 6, 7, 8])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 0, label: "B1"),
            MetroTrainDef(id: 2, lineId: 2, departDelay: 2, label: "P1"),
            MetroTrainDef(id: 3, lineId: 0, departDelay: 5, label: "R2")
        ]
        return MetroLevel(id: 3, name: "Twin Spines", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 40, segmentTravel: 1.4)
    }

    // ---- Level 5: four lines, central ring ----
    private static func level5() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.50, y: 0.30, name: "RingN", isStation: false),
            MetroNode(id: 1, x: 0.70, y: 0.50, name: "RingE", isStation: false),
            MetroNode(id: 2, x: 0.50, y: 0.70, name: "RingS", isStation: false),
            MetroNode(id: 3, x: 0.30, y: 0.50, name: "RingW", isStation: false),
            MetroNode(id: 4, x: 0.50, y: 0.08, name: "North End", isStation: true),
            MetroNode(id: 5, x: 0.92, y: 0.50, name: "East End", isStation: true),
            MetroNode(id: 6, x: 0.50, y: 0.92, name: "South End", isStation: true),
            MetroNode(id: 7, x: 0.08, y: 0.50, name: "West End", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: true),
            MetroEdge(id: 1, a: 1, b: 2, shared: true),
            MetroEdge(id: 2, a: 2, b: 3, shared: true),
            MetroEdge(id: 3, a: 3, b: 0, shared: true),
            MetroEdge(id: 4, a: 4, b: 0, shared: false),
            MetroEdge(id: 5, a: 5, b: 1, shared: false),
            MetroEdge(id: 6, a: 6, b: 2, shared: false),
            MetroEdge(id: 7, a: 7, b: 3, shared: false)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [4, 0, 1, 5]),
            MetroLineDef(id: 1, colorIndex: 1, route: [5, 1, 2, 6]),
            MetroLineDef(id: 2, colorIndex: 2, route: [6, 2, 3, 7]),
            MetroLineDef(id: 3, colorIndex: 3, route: [7, 3, 0, 4])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 1, label: "B1"),
            MetroTrainDef(id: 2, lineId: 2, departDelay: 2, label: "G1"),
            MetroTrainDef(id: 3, lineId: 3, departDelay: 3, label: "P1")
        ]
        return MetroLevel(id: 4, name: "Inner Ring", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 34, segmentTravel: 1.5)
    }

    // ---- Level 6: dense five-line network ----
    private static func level6() -> MetroLevel {
        let nodes = [
            MetroNode(id: 0, x: 0.08, y: 0.20, name: "P1", isStation: true),
            MetroNode(id: 1, x: 0.30, y: 0.30, name: "Ja", isStation: false),
            MetroNode(id: 2, x: 0.50, y: 0.40, name: "Core", isStation: false),
            MetroNode(id: 3, x: 0.70, y: 0.50, name: "Jb", isStation: false),
            MetroNode(id: 4, x: 0.92, y: 0.60, name: "P2", isStation: true),
            MetroNode(id: 5, x: 0.08, y: 0.60, name: "P3", isStation: true),
            MetroNode(id: 6, x: 0.30, y: 0.62, name: "Jc", isStation: false),
            MetroNode(id: 7, x: 0.50, y: 0.72, name: "Jd", isStation: false),
            MetroNode(id: 8, x: 0.72, y: 0.82, name: "P4", isStation: true),
            MetroNode(id: 9, x: 0.50, y: 0.10, name: "P5", isStation: true),
            MetroNode(id: 10, x: 0.90, y: 0.18, name: "P6", isStation: true)
        ]
        let edges = [
            MetroEdge(id: 0, a: 0, b: 1, shared: false),
            MetroEdge(id: 1, a: 1, b: 2, shared: true),
            MetroEdge(id: 2, a: 2, b: 3, shared: true),
            MetroEdge(id: 3, a: 3, b: 4, shared: false),
            MetroEdge(id: 4, a: 5, b: 6, shared: false),
            MetroEdge(id: 5, a: 6, b: 2, shared: true),
            MetroEdge(id: 6, a: 2, b: 7, shared: true),
            MetroEdge(id: 7, a: 7, b: 8, shared: false),
            MetroEdge(id: 8, a: 9, b: 2, shared: true),
            MetroEdge(id: 9, a: 2, b: 10, shared: false),
            MetroEdge(id: 10, a: 6, b: 7, shared: true),
            MetroEdge(id: 11, a: 1, b: 6, shared: false)
        ]
        let lines = [
            MetroLineDef(id: 0, colorIndex: 0, route: [0, 1, 2, 3, 4]),
            MetroLineDef(id: 1, colorIndex: 2, route: [5, 6, 2, 3, 4]),
            MetroLineDef(id: 2, colorIndex: 1, route: [9, 2, 7, 8]),
            MetroLineDef(id: 3, colorIndex: 3, route: [5, 6, 7, 8]),
            MetroLineDef(id: 4, colorIndex: 4, route: [0, 1, 2, 10])
        ]
        let trains = [
            MetroTrainDef(id: 0, lineId: 0, departDelay: 0, label: "R1"),
            MetroTrainDef(id: 1, lineId: 1, departDelay: 1, label: "G1"),
            MetroTrainDef(id: 2, lineId: 2, departDelay: 2, label: "B1"),
            MetroTrainDef(id: 3, lineId: 3, departDelay: 3, label: "P1"),
            MetroTrainDef(id: 4, lineId: 4, departDelay: 4, label: "O1")
        ]
        return MetroLevel(id: 5, name: "Central Tangle", nodes: nodes, edges: edges,
                          lines: lines, trains: trains, parTime: 48, segmentTravel: 1.4)
    }
}
