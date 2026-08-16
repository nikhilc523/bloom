import SwiftUI

/// The floating toast/row primitive hovering over the surface — Pinned Note,
/// insight, or undo-able event (`design/UI/IMG_4567`: floating pill rows with
/// soft shadows + inline colored action chips). `.interactive()` glass bounces
/// on tap. Body text lives on the glass chrome, kept high-contrast.
struct FloatingPillRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    var onTap: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let row = HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Bloom.Palette.deepRose)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Bloom.Palette.deepRose.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Bloom.Typography.headline)
                    .foregroundStyle(Bloom.Palette.plumInk)
                if let subtitle {
                    Text(subtitle)
                        .font(Bloom.Typography.caption)
                        .foregroundStyle(Bloom.Palette.mist)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: Bloom.Radius.pill, interactive: onTap != nil)

        Group {
            if let onTap {
                Button {
                    Bloom.Haptics.soft()
                    onTap()
                } label: { row }
                .buttonStyle(.plain)
            } else {
                row
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("floatingPillRow")
    }
}

extension FloatingPillRow where Trailing == EmptyView {
    init(icon: String, title: String, subtitle: String? = nil, onTap: (() -> Void)? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle, onTap: onTap) { EmptyView() }
    }
}

/// The single most relevant thing today — a glass card hovering above the home
/// surface (docs/research/05-ai-and-design.md §B5.4). A preset of `FloatingPillRow`.
struct FloatingPinnedNote: View {
    let title: String
    var subtitle: String?
    var icon: String = "pin.fill"
    var onTap: (() -> Void)?

    var body: some View {
        FloatingPillRow(icon: icon, title: title, subtitle: subtitle, onTap: onTap)
            .accessibilityIdentifier("floatingPinnedNote")
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        VStack(spacing: 16) {
            FloatingPinnedNote(
                title: "Period likely tomorrow",
                subtitle: "Maybe pack a few things 💗",
                onTap: {}
            )
            FloatingPillRow(icon: "sparkles", title: "Headaches cluster on days 26–28", subtitle: "Insight") {
                PastelChip(text: "See", role: .info)
            }
        }
        .padding()
    }
}
