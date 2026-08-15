import Foundation

/// A prediction is ALWAYS a range + confidence, never a single certain date
/// (docs/research/01-clinical-science.md §4; docs/product/01-data-model.md).
struct CyclePrediction: Equatable, Sendable {
    let earliestDay: Int      // days from last period start
    let mostLikelyDay: Int
    let latestDay: Int
    let confidence: Double    // 0...1

    var isRange: Bool { earliestDay != latestDay }
}

/// On-device prediction. Degrades gracefully with sparse or irregular history.
enum CyclePredictor {
    static let defaultLength = 28

    /// Predict the next period start, expressed as day-offsets from the last start.
    /// - Parameter history: recent cycle lengths (most recent last). May be empty.
    static func predict(history: [Int]) -> CyclePrediction {
        guard !history.isEmpty else {
            // No data: fall back to the population average with a wide, low-confidence band.
            return CyclePrediction(
                earliestDay: defaultLength - 3,
                mostLikelyDay: defaultLength,
                latestDay: defaultLength + 3,
                confidence: 0.3
            )
        }

        let avg = Int((Double(history.reduce(0, +)) / Double(history.count)).rounded())
        let spread = (history.max() ?? avg) - (history.min() ?? avg)   // variability in days
        let half = max(1, Int((Double(spread) / 2.0).rounded()))

        // Confidence: high for regular cycles + more data, low for irregular/sparse.
        let regularity = 1.0 - min(Double(spread) / 14.0, 1.0)          // 1 = perfectly regular
        let dataWeight = min(Double(history.count) / 6.0, 1.0)          // saturates at ~6 cycles
        let confidence = (0.3 + 0.65 * regularity * dataWeight)
            .rounded(toPlaces: 2)

        return CyclePrediction(
            earliestDay: avg - half,
            mostLikelyDay: avg,
            latestDay: avg + half,
            confidence: min(confidence, 0.95)
        )
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
