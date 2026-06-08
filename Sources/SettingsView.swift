import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var progress = MetroProgressStore.shared
    @State private var showPrivacy = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            MetroTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(MetroTheme.ink)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MetroTheme.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        // Stats card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("YOUR DISPATCH RECORD")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(MetroTheme.inkSoft)
                            statRow(label: "Total stars",
                                    value: "\(progress.totalStars()) / \(MetroLevels.all.count * 3)")
                            statRow(label: "Lines unlocked",
                                    value: "\(min(progress.highestUnlocked + 1, MetroLevels.all.count)) / \(MetroLevels.all.count)")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(card)

                        // How to play
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOW TO PLAY")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(MetroTheme.inkSoft)
                            Text("You are the dispatcher. Release and hold trains so two never ride the same shared (dashed) segment at the same moment. Trains pause at every station until you clear them. Deliver every train to its end station, and beat the par time to earn three stars.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(MetroTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(card)

                        // Privacy Policy
                        Button(action: { showPrivacy = true }) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(MetroTheme.ink)
                                Spacer()
                                MetroBackIcon(size: 18, color: MetroTheme.inkSoft)
                                    .rotationEffect(.degrees(180))
                            }
                            .padding(16)
                            .background(card)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Reset progress
                        Button(action: { showResetConfirm = true }) {
                            HStack {
                                Text("Reset Progress")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(MetroTheme.danger)
                                Spacer()
                            }
                            .padding(16)
                            .background(card)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("Timing Control")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MetroTheme.inkSoft)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }

            if showResetConfirm {
                resetConfirmOverlay
            }
        }
        .sheet(isPresented: $showPrivacy) {
            MetroWebPanel(urlString: "https://timingcontrol.org/click.php")
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(MetroTheme.cardBackground)
            .shadow(color: MetroTheme.shadow, radius: 3, y: 1)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(MetroTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(MetroTheme.primary)
        }
    }

    private var resetConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Reset all progress?")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(MetroTheme.ink)
                Text("This clears every star, best time, and unlocked line.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(MetroTheme.inkSoft)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button(action: { showResetConfirm = false }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MetroTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MetroTheme.cardBackground))
                    }
                    Button(action: {
                        progress.resetAll()
                        showResetConfirm = false
                    }) {
                        Text("Reset")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(MetroTheme.danger))
                    }
                }
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 20).fill(MetroTheme.panel))
            .frame(maxWidth: 320)
            .padding(30)
        }
    }
}
