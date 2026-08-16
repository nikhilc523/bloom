import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pink-glass design tokens (docs/research/05-ai-and-design.md §B2–B4,
/// docs/design/DESIGN-DIRECTION.md). Source of truth — never redefine these in a
/// component; import them. Glass is chrome, never a body-text background.
enum Bloom {
    // MARK: - Palette

    enum Palette {
        static let blush = Color(hex: 0xFFF0F4)      // bg base / gradient top
        static let petal = Color(hex: 0xFBD5E3)      // gradient mid, card tints
        static let rose = Color(hex: 0xF48FB6)       // primary accent, ring start
        static let deepRose = Color(hex: 0xD9538B)   // CTA, ring end, active
        static let plumInk = Color(hex: 0x3A2431)    // primary text (warm near-black)
        static let mist = Color(hex: 0x8A7480)       // captions / secondary text
        static let periwinkle = Color(hex: 0x8AA0F0) // the ONE non-pink: insight/info
        static let glassWhite = Color.white.opacity(0.62) // frosted card fill (fallback)

        /// Per-phase tint — all pink-family by design (periwinkle stays reserved
        /// for insight). Depth encodes the phase; the mood emoji carries meaning.
        static func phaseTint(_ phase: CyclePhase) -> Color {
            switch phase {
            case .menstrual: rose
            case .follicular: Color(hex: 0xF7A8C4) // fresh, lighter rose
            case .ovulation: deepRose              // peak
            case .luteal: Color(hex: 0xC98BA6)     // muted mauve-pink
            }
        }
    }

    // MARK: - Radius (always .continuous)

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Typography (minimal = few sizes, lots of air)

    enum Typography {
        /// Oversized cycle-day / phase focal number.
        static let hero = Font.system(size: 72, weight: .bold, design: .rounded)
        static let display = Font.system(size: 40, weight: .bold, design: .rounded)
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body)
        static let caption = Font.system(.subheadline)
    }

    // MARK: - Soft shadow (the puffy 3D dome)

    enum Shadow {
        static let color = Palette.deepRose.opacity(0.15) // DeepRose @ 12–18%
        static let radius: CGFloat = 24
        static let y: CGFloat = 12
    }

    // MARK: - Motion (soft + springy, never snappy-linear)

    enum Motion {
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let drift = Animation.easeInOut(duration: 7).repeatForever(autoreverses: true)
    }

    // MARK: - Haptics

    /// Soft on card tap · light on ring day-advance · success on log/check.
    enum Haptics {
        static func soft() { impact(.soft) }
        static func light() { impact(.light) }
        static func success() {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }

        private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: style).impactOccurred()
            #endif
        }
    }

    // MARK: - Background

    /// Ambient blush→petal background field with soft drifting orbs behind the
    /// glass. Orbs drift on a slow ease loop unless Reduce Motion is on.
    struct Background: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var drift = false

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Palette.blush, Palette.petal],
                    startPoint: .top,
                    endPoint: .bottom
                )
                orb(Palette.rose.opacity(0.25), size: 260)
                    .offset(x: -110, y: drift ? -200 : -240)
                orb(Palette.periwinkle.opacity(0.20), size: 220)
                    .offset(x: 130, y: drift ? 280 : 240)
            }
            .ignoresSafeArea()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.drift) { drift = true }
            }
            .accessibilityHidden(true)
        }

        private func orb(_ color: Color, size: CGFloat) -> some View {
            Circle().fill(color).frame(width: size, height: size).blur(radius: 80)
        }
    }
}

// MARK: - Glass surface (auto-upgrades to Liquid Glass on iOS 26)

/// The frosted-glass fill + lit edge + soft dome, applied to any shape. On iOS 26+
/// this uses the native `.glassEffect()` (GPU lensing, gyroscope reflections); below
/// it falls back to `.ultraThinMaterial` + a semi-transparent gradient border.
///
/// Prefer the `.glassPanel(...)` modifier or `GlassCard` over using this directly.
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = Bloom.Radius.lg
    /// Optional semantic tint (e.g. a phase color). Kept subtle — glass is chrome.
    var tint: Color?
    /// `.interactive()` glass bounces/shimmers on touch (iOS 26 only; no-op below).
    var interactive: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .modifier(GlassFill(shape: shape, tint: tint, interactive: interactive))
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Bloom.Shadow.color, radius: Bloom.Shadow.radius, x: 0, y: Bloom.Shadow.y)
    }
}

/// The version-branching fill only. Split out so the lit edge + shadow (identical
/// across versions) live in one place.
private struct GlassFill<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // The tint is a separate subtle fill *behind* content, not folded into
            // `Glass.tint()` — a tinted `.glassEffect` composites opaquely over the
            // content in offscreen snapshot rendering, hiding it.
            content
                .background { tintLayer }
                .glassEffect(interactive ? Glass.regular.interactive() : .regular, in: shape)
        } else {
            content.background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    tintLayer
                }
            }
        }
    }

    @ViewBuilder
    private var tintLayer: some View {
        if let tint { shape.fill(tint.opacity(0.16)) }
    }
}

extension View {
    /// Frost this view as glass chrome. See `GlassPanel`.
    func glassPanel(
        cornerRadius: CGFloat = Bloom.Radius.lg,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

/// A frosted glass card — padded content on a glass panel. The most common
/// surface; composes the `.glassPanel()` modifier so it auto-upgrades to
/// `.glassEffect()` on iOS 26 and falls back to `.ultraThinMaterial` below.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Bloom.Radius.lg
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .glassPanel(cornerRadius: cornerRadius, tint: tint)
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
