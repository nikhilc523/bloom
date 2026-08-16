import SwiftUI

/// A pill-shaped segmented control — day/week/phase picker
/// (`design/UI/IMG_4566`: day-of-week segmented pills). Selected segment gets a
/// DeepRose fill; idle segments read as quiet glass.
struct SegmentedPills<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    /// How to render each option's short label.
    var label: (Option) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    Bloom.Haptics.soft()
                    if reduceMotion {
                        selection = option
                    } else {
                        withAnimation(Bloom.Motion.spring) { selection = option }
                    }
                } label: {
                    Text(label(option))
                        .font(Bloom.Typography.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : Bloom.Palette.mist)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(segmentBackground(isSelected))
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("segmentedPill.\(label(option))")
            }
        }
        .padding(4)
        .glassPanel(cornerRadius: Bloom.Radius.pill)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("segmentedPills")
    }

    @ViewBuilder
    private func segmentBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            Capsule(style: .continuous).fill(Bloom.Palette.deepRose)
        } else {
            Capsule(style: .continuous).fill(.clear)
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var day = "Mon"
        var body: some View {
            ZStack {
                Bloom.Background()
                SegmentedPills(
                    options: ["Mon", "Tue", "Wed", "Thu", "Fri"],
                    selection: $day,
                    label: { $0 }
                )
                .padding()
            }
        }
    }
    return Demo()
}
