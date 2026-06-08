import SwiftUI

// Endless Rush mode screen: start screen -> live run -> game over.
struct RushView: View {
    @StateObject private var engine = MetroRushEngine()
    @ObservedObject private var progress = MetroProgressStore.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MetroTheme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    mapArea(size: CGSize(width: geo.size.width,
                                         height: geo.size.height * 0.72))
                    footer
                }

                switch engine.phase {
                case .idle:  startOverlay
                case .over:  gameOverOverlay
                case .running: EmptyView()
                }
            }
        }
        .onDisappear { engine.stop() }
    }

    // MARK: Header / footer

    private var header: some View {
        HStack(spacing: 12) {
            MetroRushTabIcon(size: 26, color: MetroTheme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rush")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.ink)
                Text("Endless dispatch")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(engine.score)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.primary)
                Text("delivered")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MetroTheme.panel.shadow(color: MetroTheme.shadow, radius: 3, y: 1))
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                MetroStarIcon(size: 14, filled: true)
                Text("Best \(progress.rushBestScore)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
            Spacer()
            if engine.phase == .running {
                Text(String(format: "%.0fs", engine.elapsed))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(MetroTheme.panel.shadow(color: MetroTheme.shadow, radius: 3, y: -1))
    }

    private func mapArea(size: CGSize) -> some View {
        RushMapView(engine: engine, screenSize: size)
            .frame(width: size.width, height: size.height)
    }

    // MARK: Overlays

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                MetroRushTabIcon(size: 48, color: MetroTheme.danger)
                Text("Rush Mode")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.ink)
                Text("Trains keep arriving at the hub. Hold and release them so two never cross the centre at once. One collision ends the run. How many can you deliver?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: { engine.startRun() }) {
                    Text("Start Rush")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.danger))
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 22).fill(MetroTheme.panel))
            .frame(maxWidth: 360)
            .padding(28)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Run Ended")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.danger)
                Text("\(engine.score)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.primary)
                Text("trains delivered")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                HStack(spacing: 6) {
                    MetroStarIcon(size: 16, filled: true)
                    Text(engine.score >= progress.rushBestScore
                         ? "New best!"
                         : "Best \(progress.rushBestScore)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MetroTheme.gold)
                }
                Button(action: { engine.startRun() }) {
                    Text("Go Again")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.primary))
                }
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 22).fill(MetroTheme.panel))
            .frame(maxWidth: 340)
            .padding(28)
        }
    }
}

// Renders the Rush hub map + spawned trains. Mirrors TrackMapView's normalized
// coordinate approach (anchored to the PARENT-passed size), inscribed + clipped.
struct RushMapView: View {
    @ObservedObject var engine: MetroRushEngine
    let screenSize: CGSize

    var body: some View {
        let boardW = max(screenSize.width, 1)
        let boardH = max(screenSize.height, 1)
        let side = max(min(boardW, boardH), 1)
        let inset: CGFloat = side * 0.10

        ZStack {
            Canvas { ctx, _ in
                draw(ctx: ctx, boardW: boardW, boardH: boardH, inset: inset)
            }
            tapTargets(boardW: boardW, boardH: boardH, inset: inset)
        }
        .frame(width: boardW, height: boardH)
        .background(MetroTheme.mapBackground)
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

    private func draw(ctx: GraphicsContext, boardW: CGFloat, boardH: CGFloat, inset: CGFloat) {
        let lvl = engine.level
        let lineW = max(min(boardW, boardH) * 0.022, 4)

        for edge in lvl.edges {
            let a = point(lvl.node(edge.a), boardW: boardW, boardH: boardH, inset: inset)
            let b = point(lvl.node(edge.b), boardW: boardW, boardH: boardH, inset: inset)
            var path = Path(); path.move(to: a); path.addLine(to: b)
            let isConflict = engine.conflictEdgeId == edge.id
            let isOccupied = engine.occupiedSegments.contains(edge.id)
            ctx.stroke(path, with: .color(MetroTheme.ink.opacity(0.18)),
                       style: StrokeStyle(lineWidth: lineW + 6, lineCap: .round))
            let baseColor: Color = isConflict ? MetroTheme.danger
                : (isOccupied ? MetroTheme.warning : MetroTheme.trackBase)
            ctx.stroke(path, with: .color(baseColor),
                       style: StrokeStyle(lineWidth: lineW, lineCap: .round))
            if !isConflict {
                ctx.stroke(path, with: .color(MetroTheme.ink.opacity(0.25)),
                           style: StrokeStyle(lineWidth: lineW * 0.35, lineCap: .butt,
                                              dash: [lineW * 0.7, lineW * 0.7]))
            }
        }

        let nodeR = max(min(boardW, boardH) * 0.035, 8)
        for node in lvl.nodes {
            let p = point(node, boardW: boardW, boardH: boardH, inset: inset)
            if node.isStation {
                let rect = CGRect(x: p.x - nodeR, y: p.y - nodeR, width: nodeR * 2, height: nodeR * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(MetroTheme.panel))
                ctx.stroke(Path(ellipseIn: rect), with: .color(MetroTheme.ink),
                           style: StrokeStyle(lineWidth: nodeR * 0.42))
            } else {
                let r = nodeR * 0.7
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(MetroTheme.inkSoft))
            }
        }

        let trainW = max(min(boardW, boardH) * 0.06, 18)
        for t in engine.trains where !t.arrived {
            let p = pointForTrain(t, boardW: boardW, boardH: boardH, inset: inset)
            let color = MetroTheme.lineColors[t.colorIndex % MetroTheme.lineColors.count]
            drawTrain(ctx: ctx, at: p, size: trainW, color: color, label: t.label, held: t.held)
        }
    }

    private func drawTrain(ctx: GraphicsContext, at p: CGPoint, size: CGFloat,
                           color: Color, label: String, held: Bool) {
        let w = size, h = size * 0.7
        let rect = CGRect(x: p.x - w/2, y: p.y - h/2, width: w, height: h)
        let body = Path(roundedRect: rect, cornerRadius: size * 0.18)
        ctx.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 2), cornerRadius: size * 0.18),
                 with: .color(.black.opacity(0.18)))
        ctx.fill(body, with: .color(color))
        ctx.stroke(body, with: .color(MetroTheme.panel), style: StrokeStyle(lineWidth: size * 0.06))
        if held {
            let ringRect = rect.insetBy(dx: -size * 0.16, dy: -size * 0.16)
            ctx.stroke(Path(roundedRect: ringRect, cornerRadius: size * 0.3),
                       with: .color(MetroTheme.warning),
                       style: StrokeStyle(lineWidth: size * 0.08, dash: [size * 0.18, size * 0.12]))
        }
        let text = Text(label).font(.system(size: size * 0.3, weight: .heavy, design: .rounded)).foregroundColor(.white)
        ctx.draw(text, at: p)
    }

    private func tapTargets(boardW: CGFloat, boardH: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            ForEach(engine.trains.filter { !$0.arrived && !$0.moving }) { t in
                let p = pointForTrain(t, boardW: boardW, boardH: boardH, inset: inset)
                let tapSize = max(min(boardW, boardH) * 0.13, 44)
                Button(action: { engine.toggleTrain(t.id) }) {
                    Color.clear.frame(width: tapSize, height: tapSize).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .position(p)
            }
        }
    }
}
