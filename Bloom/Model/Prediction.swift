import Foundation

/// A predicted date range with confidence — never a single certain date
/// (`docs/product/01-data-model.md`; `docs/research/05-ai-and-design.md`).
/// Rendered as ghost/dashed with the confidence always visible.
struct PredictionWindow: Equatable, Codable, Sendable {
    let windowStart: Date
    let windowEnd: Date
    let confidence: Double   // 0...1

    init(windowStart: Date, windowEnd: Date, confidence: Double) {
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// How a prediction was derived. Confidence degrades with sparse logging,
/// irregularity, PCOS, or perimenopause.
enum PredictionBasis: String, CaseIterable, Codable, Sendable {
    case calendar
    case bbt
    case symptothermal
}

/// An on-device prediction snapshot (`docs/product/01-data-model.md`). Computed
/// locally — never sent off device (`docs/research/05` privacy posture).
struct Prediction: Equatable, Codable, Sendable {
    var nextPeriod: PredictionWindow
    var nextOvulation: PredictionWindow?
    var basis: PredictionBasis
    var generatedAt: Date

    init(
        nextPeriod: PredictionWindow,
        nextOvulation: PredictionWindow? = nil,
        basis: PredictionBasis = .calendar,
        generatedAt: Date
    ) {
        self.nextPeriod = nextPeriod
        self.nextOvulation = nextOvulation
        self.basis = basis
        self.generatedAt = generatedAt
    }
}
