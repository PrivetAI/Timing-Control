import SwiftUI

// All icons are custom SwiftUI Shapes — NO SF Symbols, NO emoji.

// A small subway/train car glyph.
struct MetroTrainIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.22, style: .continuous)
                    .fill(color)
                    .frame(width: w * 0.78, height: h * 0.6)
                // windows
                HStack(spacing: w * 0.07) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: w * 0.05)
                            .fill(MetroTheme.panel)
                            .frame(width: w * 0.16, height: h * 0.18)
                    }
                }
                .offset(y: -h * 0.05)
                // wheels
                HStack(spacing: w * 0.34) {
                    Circle().fill(MetroTheme.ink).frame(width: w * 0.12, height: w * 0.12)
                    Circle().fill(MetroTheme.ink).frame(width: w * 0.12, height: w * 0.12)
                }
                .offset(y: h * 0.26)
            }
            .frame(width: w, height: h)
        }
        .frame(width: size, height: size)
    }
}

// A play / release (triangle) icon.
struct MetroPlayIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        Triangle()
            .fill(color)
            .frame(width: size * 0.7, height: size * 0.7)
            .frame(width: size, height: size)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// A pause / hold icon (two bars).
struct MetroHoldIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        HStack(spacing: size * 0.16) {
            RoundedRectangle(cornerRadius: size * 0.08).fill(color).frame(width: size * 0.22, height: size * 0.62)
            RoundedRectangle(cornerRadius: size * 0.08).fill(color).frame(width: size * 0.22, height: size * 0.62)
        }
        .frame(width: size, height: size)
    }
}

// A star icon for ratings.
struct MetroStarIcon: View {
    var size: CGFloat
    var filled: Bool
    var color: Color = MetroTheme.gold
    var body: some View {
        StarShape(points: 5)
            .fill(filled ? color : Color.clear)
            .overlay(
                StarShape(points: 5)
                    .stroke(filled ? color : MetroTheme.inkSoft.opacity(0.5), lineWidth: size * 0.06)
            )
            .frame(width: size, height: size)
    }
}

struct StarShape: Shape {
    var points: Int = 5
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        let step = CGFloat.pi / CGFloat(points)
        var angle = -CGFloat.pi / 2
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            angle += step
        }
        path.closeSubpath()
        return path
    }
}

// A gear-ish settings icon (custom).
struct MetroSettingsIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(color)
                    .frame(width: size * 0.14, height: size * 0.28)
                    .offset(y: -size * 0.36)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle().fill(color).frame(width: size * 0.55, height: size * 0.55)
            Circle().fill(MetroTheme.panel).frame(width: size * 0.24, height: size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

// A back chevron icon.
struct MetroBackIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: size * 0.62, y: size * 0.2))
            p.addLine(to: CGPoint(x: size * 0.32, y: size * 0.5))
            p.addLine(to: CGPoint(x: size * 0.62, y: size * 0.8))
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

// A lock icon for locked levels.
struct MetroLockIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // shackle
                Path { p in
                    p.addArc(center: CGPoint(x: w * 0.5, y: h * 0.4),
                             radius: w * 0.22,
                             startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                }
                .stroke(color, style: StrokeStyle(lineWidth: w * 0.1, lineCap: .round))
                // body
                RoundedRectangle(cornerRadius: w * 0.1)
                    .fill(color)
                    .frame(width: w * 0.62, height: h * 0.42)
                    .offset(y: h * 0.18)
            }
        }
        .frame(width: size, height: size)
    }
}

// A flag / destination icon.
struct MetroFlagIcon: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .leading) {
                Rectangle().fill(MetroTheme.ink).frame(width: w * 0.08, height: h)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.08, y: h * 0.08))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.24))
                    p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.42))
                    p.closeSubpath()
                }
                .fill(color)
            }
        }
        .frame(width: size, height: size)
    }
}

// A circular station node.
struct MetroStationDot: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        ZStack {
            Circle().fill(MetroTheme.panel)
            Circle().stroke(color, lineWidth: size * 0.18)
        }
        .frame(width: size, height: size)
    }
}
