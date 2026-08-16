import SwiftUI

/// The oversized cycle-day / phase focal number — the depth-0 focal point
/// (`design/UI/IMG_4563`, `IMG_4564`: huge minimal type, oceans of whitespace).
/// One number, one feeling; nothing competes with it.
struct HeroNumber: View {
    let value: String
    var caption: String?
    /// Small label above the number (e.g. "Day").
    var eyebrow: String?

    var body: some View {
        VStack(spacing: 4) {
            if let eyebrow {
                Text(eyebrow)
                    .font(Bloom.Typography.caption)
                    .foregroundStyle(Bloom.Palette.mist)
            }
            Text(value)
                .font(Bloom.Typography.hero)
                .foregroundStyle(Bloom.Palette.plumInk)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .font(Bloom.Typography.headline)
                    .foregroundStyle(Bloom.Palette.deepRose)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("heroNumber")
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        HeroNumber(value: "12", caption: "Follicular", eyebrow: "Day")
    }
}
