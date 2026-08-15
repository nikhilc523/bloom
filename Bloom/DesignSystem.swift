import SwiftUI

/// Pink-glass design tokens (docs/research/05-ai-and-design.md §B2–B4).
enum Bloom {
    enum Palette {
        static let blush = Color(hex: 0xFFF0F4)
        static let petal = Color(hex: 0xFBD5E3)
        static let rose = Color(hex: 0xF48FB6)
        static let deepRose = Color(hex: 0xD9538B)
        static let plumInk = Color(hex: 0x3A2431)
        static let mist = Color(hex: 0x8A7480)
        static let periwinkle = Color(hex: 0x8AA0F0)
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
    }

    /// Ambient blush→petal background field with soft drifting orbs behind the glass.
    struct Background: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Palette.blush, Palette.petal],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Circle()
                    .fill(Palette.rose.opacity(0.25))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .offset(x: -110, y: -220)
                Circle()
                    .fill(Palette.periwinkle.opacity(0.20))
                    .frame(width: 220, height: 220)
                    .blur(radius: 80)
                    .offset(x: 130, y: 260)
            }
            .ignoresSafeArea()
        }
    }
}

/// A frosted glass card. On iOS 26+ this is the natural home for `.glassEffect()`;
/// for now it uses `.ultraThinMaterial`, the backward-compatible recipe.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Bloom.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Bloom.Radius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Bloom.Palette.deepRose.opacity(0.15), radius: 24, x: 0, y: 12)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
