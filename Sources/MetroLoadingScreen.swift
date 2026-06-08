import SwiftUI

struct MetroLoadingScreen: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            MetroTheme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(MetroTheme.primary.opacity(0.12))
                        .frame(width: 120, height: 120)
                    MetroTrainIcon(size: 70, color: MetroTheme.primary)
                }
                Text("Timing Control")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.ink)

                // Animated track loader
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(MetroTheme.trackBase).frame(height: 6)
                        Capsule().fill(MetroTheme.primary)
                            .frame(width: w * 0.32, height: 6)
                            .offset(x: phase * (w * 0.68))
                    }
                }
                .frame(width: 180, height: 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}
