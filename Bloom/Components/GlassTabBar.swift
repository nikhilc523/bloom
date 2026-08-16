import SwiftUI

/// A floating frosted bottom tab bar over the ambient orbs (`design/UI/IMG_4561`).
/// Selected tab gets the DeepRose accent; idle tabs read as Mist.
struct GlassTabBar<Tab: Hashable>: View {
    struct Item: Identifiable {
        let tab: Tab
        let title: String
        let icon: String
        var id: Tab { tab }
    }

    let items: [Item]
    @Binding var selection: Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.tab == selection
                Button {
                    Bloom.Haptics.soft()
                    if reduceMotion {
                        selection = item.tab
                    } else {
                        withAnimation(Bloom.Motion.spring) { selection = item.tab }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolVariant(isSelected ? .fill : .none)
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(isSelected ? Bloom.Palette.deepRose : Bloom.Palette.mist)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("glassTab.\(item.title)")
            }
        }
        .padding(.horizontal, 8)
        .glassPanel(cornerRadius: Bloom.Radius.pill)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("glassTabBar")
    }
}

#Preview {
    struct Demo: View {
        @State private var tab = "home"
        var body: some View {
            ZStack {
                Bloom.Background()
                VStack {
                    Spacer()
                    GlassTabBar(
                        items: [
                            .init(tab: "home", title: "Home", icon: "house"),
                            .init(tab: "calendar", title: "Calendar", icon: "calendar"),
                            .init(tab: "insights", title: "Insights", icon: "sparkles"),
                        ],
                        selection: $tab
                    )
                    .padding()
                }
            }
        }
    }
    return Demo()
}
