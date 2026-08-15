import Foundation

/// A prediction is ALWAYS a range + confidence, never a single certain date
/// (docs/research/01-clinical-science.md §4; docs/product/01-data-model.md).
struct CyclePrediction: Equatable, Sendable {
    let earliestDay: Int      // days from last period start
    let mostLikelyDay: Int
    let latestDay: Int
    let confidence: Double    // 0...1

    /// Width of the uncertainty band, in days (`latest - earliest`).
    var bandWidthDays: Int { latestDay - earliestDay }

    /// Whether the prediction spans more than a single day. A well-formed
    /// prediction is always a range — see `CyclePredictor`.
    var isRange: Bool { earliestDay != latestDay }

    /// The uncertainty-band contract (`docs/research/05-ai-and-design.md` §A4/B5):
    /// a predicted day is *never* rendered as a certainty. Callers must draw the
    /// window as ghost/dashed and keep the confidence visible. Always `true` —
    /// there is no such thing as a certain prediction here.
    var requiresGhostStyling: Bool { true }
}

/// On-device calendar-method prediction. Degrades gracefully with sparse or
/// irregular history: the band widens and confidence falls, but the result is
/// always a range (`docs/product/01-data-model.md`; `docs/research/05` privacy).
///
/// The estimate blends three signals, exactly as the spec calls for:
/// - **average** cycle length → the most-likely day,
/// - **regularity** (how tightly past cycles cluster) → band width + confidence,
/// - **data-weight** (how many cycles we've seen) → confidence.
enum CyclePredictor {
    static let defaultLength = 28

    /// A cycle-to-cycle drift of this many days reads as "irregular"
    /// (`docs/research/01` §3) — regularity is scored against it.
    static let irregularShiftDays = 7.0

    /// Confidence floor for any prediction we surface, and the cap (we never
    /// claim certainty). The floor keeps a usable-but-humble estimate on-screen.
    static let minConfidence = 0.3
    static let maxConfidence = 0.95

    /// Data-weight saturates once we've seen this many cycles — more history
    /// beyond it barely moves confidence.
    static let dataWeightSaturationCycles = 6.0

    /// Predict the next period start, expressed as day-offsets from the last
    /// start.
    /// - Parameter history: recent cycle lengths (most recent last). May be empty.
    static func predict(history: [Int]) -> CyclePrediction {
        guard !history.isEmpty else {
            // No data: fall back to the population average with a wide, low-
            // confidence band. Still a range — never a bare date.
            return CyclePrediction(
                earliestDay: defaultLength - 3,
                mostLikelyDay: defaultLength,
                latestDay: defaultLength + 3,
                confidence: minConfidence
            )
        }

        let count = Double(history.count)
        let mean = Double(history.reduce(0, +)) / count
        let avg = Int(mean.rounded())
        let sd = standardDeviation(of: history, mean: mean)

        // Band: at least ±1 (so it always reads as a range), widening with the
        // spread of past cycles. `ceil(sd)` keeps the band honest for noisy data.
        let half = max(1, Int(sd.rounded(.up)))

        // Regularity: 1 when cycles are identical, 0 once the spread reaches the
        // clinical "irregular" drift. Data-weight rewards a longer history.
        let regularity = 1.0 - min(sd / irregularShiftDays, 1.0)
        let dataWeight = min(count / dataWeightSaturationCycles, 1.0)
        let confidence = (minConfidence + (maxConfidence - minConfidence) * regularity * dataWeight)
            .rounded(toPlaces: 2)

        return CyclePrediction(
            earliestDay: avg - half,
            mostLikelyDay: avg,
            latestDay: avg + half,
            confidence: min(max(confidence, 0), maxConfidence)
        )
    }

    /// Produce a concrete dated `Prediction` for the next period from the last
    /// period start. Returns `nil` for life stages where calendar prediction is
    /// not meaningful (pregnancy/postpartum/perimenopause) — we don't fake a
    /// window we can't stand behind (`docs/research/01` §5).
    static func nextPeriodPrediction(
        lastPeriodStart: Date,
        history: [Int],
        mode: LifeStageMode = .cycle,
        generatedAt: Date,
        calendar: Calendar = .current
    ) -> Prediction? {
        guard mode.supportsCyclePrediction else { return nil }

        let p = predict(history: history)
        let start = calendar.date(byAdding: .day, value: p.earliestDay, to: lastPeriodStart) ?? lastPeriodStart
        let end = calendar.date(byAdding: .day, value: p.latestDay, to: lastPeriodStart) ?? lastPeriodStart

        return Prediction(
            nextPeriod: PredictionWindow(windowStart: start, windowEnd: end, confidence: p.confidence),
            basis: .calendar,
            generatedAt: generatedAt
        )
    }

    /// Population standard deviation (0 for a single sample) — the spread signal
    /// behind regularity and band width.
    private static func standardDeviation(of values: [Int], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let variance = values.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(values.count)
        return variance.squareRoot()
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
