import SwiftUI

/// A frosted glass card tinted per phase, carrying the phase's mood emoji, a
/// short calm insight, and 1–2 tips (docs/research/05-ai-and-design.md §B5.2,
/// §A2). Tap-to-expand in place — data lives at depth, never on the home surface.
struct PhaseCard: View {
    let phase: CyclePhase
    /// One calm sentence about the phase (clinician-reviewed template copy).
    let summary: String
    var tips: [String] = []

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { Bloom.Palette.phaseTint(phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                // Rive 3D-emoji wired in Stage 7; SF Symbol placeholder now.
                Image(systemName: MoodForecast.forPhase(phase).symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(phase.label) phase")
                        .font(Bloom.Typography.title)
                        .foregroundStyle(Bloom.Palette.plumInk)
                    PastelChip(text: phase.label, role: .phase(phase))
                }
                Spacer(minLength: 0)
                if !tips.isEmpty {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Bloom.Palette.mist)
                }
            }

            Text(summary)
                .font(Bloom.Typography.body)
                .foregroundStyle(Bloom.Palette.plumInk)
                .fixedSize(horizontal: false, vertical: true)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips, id: \.self) { tip in
                        Label(tip, systemImage: "leaf.fill")
                            .font(Bloom.Typography.caption)
                            .foregroundStyle(Bloom.Palette.mist)
                            .labelStyle(.titleAndIcon)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .glassPanel(tint: tint)
        .contentShape(RoundedRectangle(cornerRadius: Bloom.Radius.lg, style: .continuous))
        .onTapGesture(perform: toggle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phase.label) phase. \(summary)")
        .accessibilityHint(tips.isEmpty ? "" : (expanded ? "Collapse tips" : "Expand tips"))
        .accessibilityAddTraits(tips.isEmpty ? [] : .isButton)
        .accessibilityAction {
            toggle() // VoiceOver double-tap expands/collapses, not just the finger tap
        }
        .accessibilityIdentifier("phaseCard")
    }

    private func toggle() {
        guard !tips.isEmpty else { return }
        Bloom.Haptics.soft()
        if reduceMotion {
            expanded.toggle()
        } else {
            withAnimation(Bloom.Motion.spring) { expanded.toggle() }
        }
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        PhaseCard(
            phase: .luteal,
            summary: "You're in your luteal phase — cravings, lower energy, and a shorter fuse are all normal right now.",
            tips: ["Go easy on caffeine", "A short walk helps the mood dip"]
        )
        .padding()
    }
}
