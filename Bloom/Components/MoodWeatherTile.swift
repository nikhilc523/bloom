import SwiftUI

/// "Today's mood forecast" mapped to a weather metaphor — the signature charm
/// moment (docs/research/05-ai-and-design.md §B5.3). Phase (+ symptoms later)
/// maps to a sunny/cloudy/stormy face.
enum MoodForecast: String, CaseIterable, Sendable {
    case sunny, partlyCloudy, cloudy, stormy

    /// SF Symbol placeholder — the Rive 3D-emoji face is wired in Stage 7.
    var symbol: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy: "cloud.fill"
        case .stormy: "cloud.rain.fill"
        }
    }

    var caption: String {
        switch self {
        case .sunny: "Bright and steady"
        case .partlyCloudy: "A little up and down"
        case .cloudy: "Low energy — be kind to yourself"
        case .stormy: "Tender day — take it slow"
        }
    }

    /// The calm default mapping from cycle phase.
    static func forPhase(_ phase: CyclePhase) -> MoodForecast {
        switch phase {
        case .menstrual: .stormy
        case .follicular: .sunny
        case .ovulation: .partlyCloudy
        case .luteal: .cloudy
        }
    }
}

/// The Mood Weather tile: a glass tile with the mood face + a one-line forecast.
struct MoodWeatherTile: View {
    let mood: MoodForecast
    var phase: CyclePhase?

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        phase.map(Bloom.Palette.phaseTint) ?? Bloom.Palette.rose
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: mood.symbol)
                .font(.system(size: 44))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.7)
            Text("Today")
                .font(Bloom.Typography.caption)
                .foregroundStyle(Bloom.Palette.mist)
            Text(mood.caption)
                .font(Bloom.Typography.headline)
                .foregroundStyle(Bloom.Palette.plumInk)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassPanel(tint: tint)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Bloom.Motion.spring) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's mood forecast: \(mood.caption)")
        .accessibilityIdentifier("moodWeatherTile")
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        MoodWeatherTile(mood: .cloudy, phase: .luteal)
            .padding()
    }
}
