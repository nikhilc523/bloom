import SwiftUI

/// A tinted glass pill for tags / categories / status / actions
/// (`design/UI/IMG_4562`, `IMG_4565`). One accent = one meaning:
/// DeepRose = *your* action, Periwinkle = insight/info, Mist = neutral,
/// phase = the cycle phase's pink-family tint.
struct PastelChip: View {
    enum Role: Equatable {
        case action   // DeepRose — your CTA
        case info     // Periwinkle — the one non-pink, insight/info
        case neutral  // Mist — quiet metadata
        case phase(CyclePhase)

        var tint: Color {
            switch self {
            case .action: Bloom.Palette.deepRose
            case .info: Bloom.Palette.periwinkle
            case .neutral: Bloom.Palette.mist
            case .phase(let p): Bloom.Palette.phaseTint(p)
            }
        }
    }

    let text: String
    var role: Role = .neutral
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.caption.weight(.semibold))
            }
            Text(text).font(.footnote.weight(.semibold))
        }
        // Chip text sits on a solid tint, never on glass — contrast is safe.
        .foregroundStyle(role.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous).fill(role.tint.opacity(0.16))
        )
        .overlay(
            Capsule(style: .continuous).stroke(role.tint.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("pastelChip")
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        VStack(spacing: 16) {
            PastelChip(text: "Log period", role: .action, icon: "drop.fill")
            PastelChip(text: "Insight", role: .info, icon: "sparkles")
            PastelChip(text: "Day 5", role: .neutral)
            PastelChip(text: "Luteal", role: .phase(.luteal))
        }
    }
}
