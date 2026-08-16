import SwiftUI

/// A glass row with a DeepRose check — logging steps / onboarding tasks
/// (`design/UI/IMG_4566`: dark checklist rows with a single pink accent check).
/// Body text sits on the glass panel's chrome, kept high-contrast against it.
struct ChecklistRow: View {
    let title: String
    var subtitle: String?
    let isDone: Bool
    var onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Bloom.Palette.deepRose : Bloom.Palette.mist)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Bloom.Typography.headline)
                        .foregroundStyle(Bloom.Palette.plumInk)
                        .strikethrough(isDone, color: Bloom.Palette.mist)
                    if let subtitle {
                        Text(subtitle)
                            .font(Bloom.Typography.caption)
                            .foregroundStyle(Bloom.Palette.mist)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassPanel(cornerRadius: Bloom.Radius.md)
            .contentShape(RoundedRectangle(cornerRadius: Bloom.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isDone ? "Completed" : "Not completed")
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("checklistRow")
    }

    private func toggle() {
        if isDone {
            Bloom.Haptics.soft()
        } else {
            Bloom.Haptics.success()
        }
        if reduceMotion {
            onToggle()
        } else {
            withAnimation(Bloom.Motion.spring) { onToggle() }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var done = false
        var body: some View {
            ZStack {
                Bloom.Background()
                VStack(spacing: 12) {
                    ChecklistRow(title: "Log today's flow", subtitle: "Takes 5 seconds", isDone: done) { done.toggle() }
                    ChecklistRow(title: "Connect Apple Health", isDone: true) {}
                }
                .padding()
            }
        }
    }
    return Demo()
}
