import SwiftUI

// Renders the track network + trains. The map uses normalized [0,1] node coords scaled
// into the available area passed by the PARENT (GeometryReader), NOT the Canvas-provided
// size (which differs on iOS 26). The board is inscribed with min() and clipped so it never
// overflows neighbouring UI.
struct TrackMapView: View {
    @ObservedObject var engine: MetroGameEngine
    let screenSize: CGSize   // parent-measured available area for the map

    var body: some View {
        let side = max(min(screenSize.width, screenSize.height), 1)
        // Map occupies a square inscribed in the available area, centered.
        let boardW = max(screenSize.width, 1)
        let boardH = max(screenSize.height, 1)
        let inset: CGFloat = side * 0.06

        ZStack {
            Canvas { ctx, _ in
                drawNetwork(ctx: ctx, boardW: boardW, boardH: boardH, inset: inset)
            }
            // Tap targets for trains sitting at nodes (Canvas can't receive taps per-train).
            trainTapTargets(boardW: boardW, boardH: boardH, inset: inset)
        }
        .frame(width: boardW, height: boardH)
        .background(MetroTheme.panel)
        .clipped()
    }

    private func point(_ node: MetroNode, boardW: CGFloat, boardH: CGFloat, inset: CGFloat) -> CGPoint {
        let usableW = boardW - inset * 2
        let usableH = boardH - inset * 2
        return CGPoint(x: inset + node.x * usableW, y: inset + node.y * usableH)
    }

    private func pointForTrain(_ t: MetroTrain, boardW: CGFloat, boardH: CGFloat, inset: CGFloat) -> CGPoint {
        let here = engine.level.node(t.currentNode)
        let p0 = point(here, boardW: boardW, boardH: boardH, inset: inset)
        if t.moving, let nId = t.nextNode {
            let next = engine.level.node(nId)
            let p1 = point(next, boardW: boardW, boardH: boardH, inset: inset)
            return CGPoint(x: p0.x + (p1.x - p0.x) * t.progress,
                           y: p0.y + (p1.y - p0.y) * t.progress)
        }
        return p0
    }

    private func drawNetwork(ctx: GraphicsContext, boardW: CGFloat, boardH: CGFloat, inset: CGFloat) {
        let lvl = engine.level
        let lineW = max(min(boardW, boardH) * 0.022, 4)

        // 1. Draw all edges (base track).
        for edge in lvl.edges {
            let a = point(lvl.node(edge.a), boardW: boardW, boardH: boardH, inset: inset)
            let b = point(lvl.node(edge.b), boardW: boardW, boardH: boardH, inset: inset)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)

            let isConflict = engine.conflictEdgeId == edge.id
            let isOccupied = engine.occupiedSegments.contains(edge.id)

            // Outer casing
            ctx.stroke(path, with: .color(MetroTheme.ink.opacity(0.18)),
                       style: StrokeStyle(lineWidth: lineW + 6, lineCap: .round))

            let baseColor: Color
            if isConflict {
                baseColor = MetroTheme.danger
            } else if edge.shared {
                baseColor = isOccupied ? MetroTheme.warning : MetroTheme.trackBase
            } else {
                baseColor = MetroTheme.trackBase
            }
            ctx.stroke(path, with: .color(baseColor),
                       style: StrokeStyle(lineWidth: lineW, lineCap: .round))

            // Mark shared segments with a dashed hazard overlay.
            if edge.shared && !isConflict {
                ctx.stroke(path, with: .color(MetroTheme.ink.opacity(0.25)),
                           style: StrokeStyle(lineWidth: lineW * 0.35, lineCap: .butt, dash: [lineW * 0.7, lineW * 0.7]))
            }
        }

        // 2. Draw a thin coloured rail for each line so routes are visible.
        for line in lvl.lines {
            let color = MetroTheme.lineColors[line.colorIndex % MetroTheme.lineColors.count]
            var path = Path()
            for (i, nodeId) in line.route.enumerated() {
                let p = point(lvl.node(nodeId), boardW: boardW, boardH: boardH, inset: inset)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            ctx.stroke(path, with: .color(color.opacity(0.55)),
                       style: StrokeStyle(lineWidth: lineW * 0.4, lineCap: .round, lineJoin: .round))
        }

        // 3. Draw nodes.
        let nodeR = max(min(boardW, boardH) * 0.03, 7)
        for node in lvl.nodes {
            let p = point(node, boardW: boardW, boardH: boardH, inset: inset)
            if node.isStation {
                // station: ring
                let rect = CGRect(x: p.x - nodeR, y: p.y - nodeR, width: nodeR * 2, height: nodeR * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(MetroTheme.panel))
                ctx.stroke(Path(ellipseIn: rect), with: .color(MetroTheme.ink),
                           style: StrokeStyle(lineWidth: nodeR * 0.42))
            } else {
                // junction: small dot
                let r = nodeR * 0.55
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(MetroTheme.inkSoft))
            }
        }

        // 4. Draw destination flags (last node of each line) subtly highlighted.
        // (kept minimal; destinations are stations and already drawn).

        // 5. Draw trains.
        let trainW = max(min(boardW, boardH) * 0.055, 16)
        for t in engine.trains where !t.arrived {
            let p = pointForTrain(t, boardW: boardW, boardH: boardH, inset: inset)
            let color = MetroTheme.lineColors[t.colorIndex % MetroTheme.lineColors.count]
            drawTrain(ctx: ctx, at: p, size: trainW, color: color, label: t.label,
                      held: t.held, available: t.available, moving: t.moving)
        }
    }

    private func drawTrain(ctx: GraphicsContext, at p: CGPoint, size: CGFloat,
                           color: Color, label: String, held: Bool, available: Bool, moving: Bool) {
        let w = size
        let h = size * 0.7
        let rect = CGRect(x: p.x - w/2, y: p.y - h/2, width: w, height: h)
        let body = Path(roundedRect: rect, cornerRadius: size * 0.18)

        // shadow
        let shadowRect = rect.offsetBy(dx: 0, dy: 2)
        ctx.fill(Path(roundedRect: shadowRect, cornerRadius: size * 0.18), with: .color(.black.opacity(0.18)))

        ctx.fill(body, with: .color(color))
        ctx.stroke(body, with: .color(MetroTheme.panel), style: StrokeStyle(lineWidth: size * 0.06))

        // hold indicator ring (amber) when held & available; gray when waiting on delay
        if held {
            let ringColor = available ? MetroTheme.warning : MetroTheme.inkSoft
            let ringRect = rect.insetBy(dx: -size * 0.16, dy: -size * 0.16)
            ctx.stroke(Path(roundedRect: ringRect, cornerRadius: size * 0.3),
                       with: .color(ringColor),
                       style: StrokeStyle(lineWidth: size * 0.08, dash: [size * 0.18, size * 0.12]))
        }

        // label text
        let text = Text(label).font(.system(size: size * 0.32, weight: .heavy, design: .rounded)).foregroundColor(.white)
        ctx.draw(text, at: p)
    }

    // Invisible buttons over each train sitting at a node so the player can hold/release.
    private func trainTapTargets(boardW: CGFloat, boardH: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            ForEach(engine.trains.filter { !$0.arrived && !$0.moving }) { t in
                let p = pointForTrain(t, boardW: boardW, boardH: boardH, inset: inset)
                let tapSize = max(min(boardW, boardH) * 0.12, 40)
                Button(action: { engine.toggleTrain(t.id) }) {
                    Color.clear.frame(width: tapSize, height: tapSize).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .position(p)
                .disabled(!t.available)
            }
        }
    }
}
