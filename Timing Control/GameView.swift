import SwiftUI

struct GameView: View {
    let levelIndex: Int
    var onExit: () -> Void

    @StateObject private var engine: MetroGameEngine
    @ObservedObject private var progress = MetroProgressStore.shared
    @State private var showInstructions = true
    @State private var didRecord = false

    init(levelIndex: Int, onExit: @escaping () -> Void) {
        self.levelIndex = levelIndex
        self.onExit = onExit
        _engine = StateObject(wrappedValue: MetroGameEngine(level: MetroLevels.get(levelIndex)))
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                MetroTheme.background.ignoresSafeArea()
                if isLandscape {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }

                overlays(geo: geo)
            }
        }
        .onAppear {
            if !showInstructions { engine.start() }
        }
        .onDisappear { engine.stop() }
    }

    // MARK: Layouts

    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            hudBar(width: geo.size.width)
            mapArea(size: CGSize(width: geo.size.width, height: geo.size.height * 0.66))
            controlBar(width: geo.size.width)
        }
    }

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                hudBar(width: geo.size.width * 0.30)
                Spacer()
                controlBar(width: geo.size.width * 0.30)
            }
            .frame(width: geo.size.width * 0.30)
            .padding(.vertical, 8)

            mapArea(size: CGSize(width: geo.size.width * 0.70, height: geo.size.height))
        }
    }

    private func mapArea(size: CGSize) -> some View {
        TrackMapView(engine: engine, screenSize: size)
            .frame(width: size.width, height: size.height)
    }

    // MARK: HUD

    private func hudBar(width: CGFloat) -> some View {
        let lvl = engine.level
        let arrived = engine.trains.filter { $0.arrived }.count
        let total = engine.trains.count
        return HStack(spacing: 10) {
            Button(action: { engine.stop(); onExit() }) {
                MetroBackIcon(size: 22, color: MetroTheme.primary)
                    .padding(8)
                    .background(Circle().fill(MetroTheme.cardBackground))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lvl.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(MetroTheme.ink)
                    .lineLimit(1)
                Text("Level \(levelIndex + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fs", engine.elapsed))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.primary)
                Text("\(arrived)/\(total) arrived")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MetroTheme.panel.shadow(color: MetroTheme.shadow, radius: 3, y: 1))
    }

    // MARK: Control bar — list of trains with release/hold buttons.

    private func controlBar(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text("DISPATCH BOARD")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(engine.trains) { t in
                        trainChip(t)
                    }
                }
                .padding(.vertical, 2)
            }
            HStack(spacing: 8) {
                Button(action: restart) {
                    Text("Restart")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MetroTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(MetroTheme.cardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MetroTheme.primary.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MetroTheme.panel.shadow(color: MetroTheme.shadow, radius: 3, y: -1))
    }

    private func trainChip(_ t: MetroTrain) -> some View {
        let color = MetroTheme.lineColors[t.colorIndex % MetroTheme.lineColors.count]
        let canToggle = !t.arrived && !t.moving && t.available
        let statusText: String = {
            if t.arrived { return "Arrived" }
            if t.moving { return "En route" }
            if !t.available { return "Wait \(Int(ceil(max(0, t.departDelay - engine.elapsed))))s" }
            return t.held ? "Held" : "Clear"
        }()
        return Button(action: { engine.toggleTrain(t.id) }) {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    MetroTrainIcon(size: 22, color: color)
                    Text(t.label)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(MetroTheme.ink)
                }
                ZStack {
                    if t.arrived {
                        MetroFlagIcon(size: 16, color: MetroTheme.success)
                    } else if t.moving {
                        MetroPlayIcon(size: 14, color: MetroTheme.inkSoft)
                    } else if t.held {
                        MetroHoldIcon(size: 14, color: MetroTheme.warning)
                    } else {
                        MetroPlayIcon(size: 14, color: MetroTheme.success)
                    }
                }
                .frame(height: 18)
                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 76)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(MetroTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(canToggle ? color.opacity(0.6) : MetroTheme.trackBase, lineWidth: canToggle ? 2 : 1)
            )
            .opacity(t.arrived ? 0.55 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canToggle)
    }

    // MARK: Overlays (instructions, win, fail)

    @ViewBuilder
    private func overlays(geo: GeometryProxy) -> some View {
        if showInstructions {
            instructionsOverlay
        }
        switch engine.state {
        case .won(let stars, let time):
            resultOverlay(won: true, stars: stars, time: time, reason: nil)
                .onAppear { recordIfNeeded(stars: stars, time: time) }
        case .failed(let reason):
            resultOverlay(won: false, stars: 0, time: engine.elapsed, reason: reason)
        case .running:
            EmptyView()
        }
    }

    private var instructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("How to Dispatch")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.ink)
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(icon: AnyView(MetroPlayIcon(size: 18, color: MetroTheme.success)),
                                   text: "Tap a train (on the map or the board) to release it from a station.")
                    instructionRow(icon: AnyView(MetroHoldIcon(size: 18, color: MetroTheme.warning)),
                                   text: "Tap again to hold it. Trains auto-stop at every station.")
                    instructionRow(icon: AnyView(MetroHazardIcon(size: 18)),
                                   text: "Dashed segments are shared track. Never let two trains ride the same one at once.")
                    instructionRow(icon: AnyView(MetroFlagIcon(size: 18, color: MetroTheme.success)),
                                   text: "Get every train to its end station. Finish under par for 3 stars.")
                }
                .padding(.horizontal, 6)

                Button(action: {
                    showInstructions = false
                    engine.start()
                }) {
                    Text("Start Run")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(MetroTheme.primary))
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 22).fill(MetroTheme.panel))
            .frame(maxWidth: 360)
            .padding(28)
        }
    }

    private func instructionRow(icon: AnyView, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            icon.frame(width: 26, height: 26)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(MetroTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func resultOverlay(won: Bool, stars: Int, time: Double, reason: String?) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(won ? "Line Cleared" : "Service Disrupted")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(won ? MetroTheme.success : MetroTheme.danger)

                if won {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            MetroStarIcon(size: 42, filled: i < stars)
                        }
                    }
                    Text(String(format: "Time: %.1fs   Par: %.0fs", time, engine.level.parTime))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(MetroTheme.inkSoft)
                } else {
                    Text(reason ?? "A conflict occurred.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(MetroTheme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    if won && levelIndex < MetroLevels.totalLevels - 1 {
                        Button(action: { onExit() }) {
                            resultButtonLabel("Level Map", filled: true)
                        }
                    } else {
                        Button(action: restart) {
                            resultButtonLabel("Try Again", filled: true)
                        }
                    }
                    Button(action: restart) {
                        resultButtonLabel(won ? "Replay" : "Retry", filled: false)
                    }
                    Button(action: { onExit() }) {
                        resultButtonLabel("Level Map", filled: false)
                    }
                }
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 22).fill(MetroTheme.panel))
            .frame(maxWidth: 360)
            .padding(28)
        }
    }

    private func resultButtonLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundColor(filled ? .white : MetroTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(filled ? MetroTheme.primary : MetroTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(filled ? Color.clear : MetroTheme.primary.opacity(0.35), lineWidth: 1)
            )
    }

    // MARK: Actions

    private func restart() {
        didRecord = false
        engine.reset()
        engine.start()
    }

    private func recordIfNeeded(stars: Int, time: Double) {
        guard !didRecord else { return }
        didRecord = true
        progress.recordResult(level: levelIndex, stars: stars, time: time,
                              totalLevels: MetroLevels.totalLevels)
    }
}

// A small hazard (warning) icon used in instructions.
struct MetroHazardIcon: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            Triangle()
                .rotation(.degrees(90))
                .fill(MetroTheme.warning)
            Rectangle()
                .fill(MetroTheme.ink)
                .frame(width: size * 0.08, height: size * 0.3)
                .offset(y: size * 0.02)
            Circle()
                .fill(MetroTheme.ink)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(y: size * 0.26)
        }
        .frame(width: size, height: size)
    }
}
