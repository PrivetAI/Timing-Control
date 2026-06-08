import SwiftUI

// A user-selectable cosmetic skin. Each skin changes the line palette, the train
// accent style and the map background. Skins unlock by total stars earned.
// All colours are custom — no image assets, no device-dark-mode dependence.
struct MetroSkin: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let starsRequired: Int
    let lineColors: [Color]
    let mapBackground: Color
    // Train body style: how the train car is tinted/edged on the map.
    let trainStrokeLight: Bool   // true = light (panel) edge, false = dark ink edge
    // A representative swatch colour for the skin card.
    var swatch: Color { lineColors.first ?? MetroTheme.primary }
}

enum MetroSkins {
    // Catalog in unlock order (ascending star thresholds).
    static let all: [MetroSkin] = [
        MetroSkin(
            id: "classic",
            name: "Classic Transit",
            blurb: "The standard dispatcher palette.",
            starsRequired: 0,
            lineColors: [
                Color(red: 0.84, green: 0.24, blue: 0.24),
                Color(red: 0.10, green: 0.42, blue: 0.78),
                Color(red: 0.16, green: 0.62, blue: 0.38),
                Color(red: 0.62, green: 0.30, blue: 0.72),
                Color(red: 0.93, green: 0.55, blue: 0.10)
            ],
            mapBackground: Color(red: 1.0, green: 1.0, blue: 1.0),
            trainStrokeLight: true
        ),
        MetroSkin(
            id: "sunset",
            name: "Sunset Loop",
            blurb: "Warm dusk tones across the network.",
            starsRequired: 15,
            lineColors: [
                Color(red: 0.91, green: 0.36, blue: 0.27),
                Color(red: 0.96, green: 0.60, blue: 0.18),
                Color(red: 0.86, green: 0.27, blue: 0.49),
                Color(red: 0.55, green: 0.30, blue: 0.62),
                Color(red: 0.97, green: 0.78, blue: 0.28)
            ],
            mapBackground: Color(red: 1.0, green: 0.97, blue: 0.93),
            trainStrokeLight: true
        ),
        MetroSkin(
            id: "forest",
            name: "Forest Lines",
            blurb: "Cool greens and deep teal rails.",
            starsRequired: 40,
            lineColors: [
                Color(red: 0.18, green: 0.55, blue: 0.36),
                Color(red: 0.11, green: 0.45, blue: 0.46),
                Color(red: 0.46, green: 0.62, blue: 0.22),
                Color(red: 0.30, green: 0.40, blue: 0.66),
                Color(red: 0.74, green: 0.58, blue: 0.20)
            ],
            mapBackground: Color(red: 0.96, green: 0.98, blue: 0.95),
            trainStrokeLight: true
        ),
        MetroSkin(
            id: "neon",
            name: "Neon Night",
            blurb: "Electric rails on a slate board.",
            starsRequired: 80,
            lineColors: [
                Color(red: 0.95, green: 0.25, blue: 0.55),
                Color(red: 0.20, green: 0.78, blue: 0.92),
                Color(red: 0.40, green: 0.88, blue: 0.45),
                Color(red: 0.70, green: 0.45, blue: 0.95),
                Color(red: 0.98, green: 0.78, blue: 0.25)
            ],
            mapBackground: Color(red: 0.90, green: 0.92, blue: 0.96),
            trainStrokeLight: true
        ),
        MetroSkin(
            id: "mono",
            name: "Blueprint",
            blurb: "Crisp ink-and-azure draughtsman style.",
            starsRequired: 130,
            lineColors: [
                Color(red: 0.10, green: 0.42, blue: 0.78),
                Color(red: 0.20, green: 0.55, blue: 0.85),
                Color(red: 0.32, green: 0.36, blue: 0.55),
                Color(red: 0.45, green: 0.62, blue: 0.88),
                Color(red: 0.14, green: 0.30, blue: 0.58)
            ],
            mapBackground: Color(red: 0.93, green: 0.95, blue: 0.99),
            trainStrokeLight: true
        )
    ]

    static func skin(id: String) -> MetroSkin {
        all.first(where: { $0.id == id }) ?? all[0]
    }

    // The currently selected skin (falls back to classic if the selected one is
    // somehow no longer unlocked or unknown).
    static var active: MetroSkin {
        let sel = MetroProgressStore.shared.selectedSkinId
        return skin(id: sel)
    }

    static func isUnlocked(_ skin: MetroSkin, totalStars: Int) -> Bool {
        totalStars >= skin.starsRequired
    }
}
