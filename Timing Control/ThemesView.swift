import SwiftUI

// Themes / skins picker. Each skin unlocks at a total-stars threshold and changes
// the line palette + map background app-wide via the selected MetroSkin.
struct ThemesView: View {
    @ObservedObject private var progress = MetroProgressStore.shared

    var body: some View {
        ZStack {
            MetroTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    MetroThemeIcon(size: 28, color: MetroSkins.active.swatch)
                    Text("Themes")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(MetroTheme.ink)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Text("Unlock new palettes by earning stars. The chosen theme applies across every map.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(MetroSkins.all) { skin in
                            skinCard(skin)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private func skinCard(_ skin: MetroSkin) -> some View {
        let total = progress.totalStars()
        let unlocked = MetroSkins.isUnlocked(skin, totalStars: total)
        let selected = progress.selectedSkinId == skin.id
        return Button(action: {
            guard unlocked else { return }
            progress.selectedSkinId = skin.id
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(skin.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(unlocked ? MetroTheme.ink : MetroTheme.inkSoft)
                        Text(skin.blurb)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                    }
                    Spacer()
                    if selected {
                        Text("Active")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(MetroTheme.success))
                    } else if !unlocked {
                        HStack(spacing: 4) {
                            MetroLockIcon(size: 14, color: MetroTheme.inkSoft)
                            Text("\(skin.starsRequired)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(MetroTheme.inkSoft)
                            MetroStarIcon(size: 12, filled: true)
                        }
                    }
                }
                // palette swatches preview
                HStack(spacing: 8) {
                    ForEach(Array(skin.lineColors.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(c)
                            .frame(height: 22)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(skin.mapBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MetroTheme.trackBase, lineWidth: 1))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(MetroTheme.cardBackground)
                .shadow(color: MetroTheme.shadow, radius: 3, y: 1))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(selected ? MetroTheme.success : (unlocked ? skin.swatch.opacity(0.4) : Color.clear),
                        lineWidth: selected ? 2.5 : 1.5))
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!unlocked)
    }
}
