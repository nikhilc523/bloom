import SwiftUI

/// The hero component: a circular progress ring showing the current cycle day
/// with a Rose→DeepRose gradient fill and a lit-glass edge.
struct CycleRing: View {
    let day: Int
    let length: Int

    private var progress: Double {
        guard length > 0 else { return 0 }
        return min(Double(day) / Double(length), 1)
    }

    private var phaseLabel: String {
        Cycle(lengthDays: length).phase(onDay: day).label
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Bloom.Palette.rose.opacity(0.18), lineWidth: 20)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Bloom.Palette.rose, Bloom.Palette.deepRose],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("Day")
                    .font(.subheadline)
                    .foregroundStyle(Bloom.Palette.mist)
                Text("\(day)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Bloom.Palette.plumInk)
                Text(phaseLabel)
                    .font(.headline)
                    .foregroundStyle(Bloom.Palette.deepRose)
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("cycleRing")
        .accessibilityLabel("Cycle day")
        .accessibilityValue("Day \(day) of \(length), \(phaseLabel) phase")
    }
}
