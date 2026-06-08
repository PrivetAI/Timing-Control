import SwiftUI

// Fixed custom palette — theme independent (does NOT respond to device dark mode).
// The cosmetic line/train/map palette is driven by the user-selected MetroSkin
// (see MetroSkins / ThemesView). lineColors and the map tones resolve through the
// currently active skin so the choice applies app-wide.
enum MetroTheme {
    // Background tones (warm off-white transit-map paper feel)
    static let background = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let panel = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let cardBackground = Color(red: 0.99, green: 0.99, blue: 0.97)

    // Track / ink tones
    static let trackBase = Color(red: 0.82, green: 0.82, blue: 0.80)
    static let ink = Color(red: 0.13, green: 0.15, blue: 0.20)
    static let inkSoft = Color(red: 0.42, green: 0.45, blue: 0.50)

    // Accent system colours (the dispatcher palette)
    static let primary = Color(red: 0.10, green: 0.42, blue: 0.78)      // signal blue
    static let primaryDark = Color(red: 0.06, green: 0.30, blue: 0.58)
    static let success = Color(red: 0.16, green: 0.62, blue: 0.38)      // clear green
    static let warning = Color(red: 0.95, green: 0.66, blue: 0.13)      // hold amber
    static let danger = Color(red: 0.84, green: 0.24, blue: 0.24)       // conflict red
    static let gold = Color(red: 0.93, green: 0.74, blue: 0.20)         // star gold

    // Line colours used for the metro lines on the map — resolve through the active skin.
    static var lineColors: [Color] { MetroSkins.active.lineColors }

    // Map background tone — resolve through the active skin.
    static var mapBackground: Color { MetroSkins.active.mapBackground }

    static let shadow = Color.black.opacity(0.12)
}
