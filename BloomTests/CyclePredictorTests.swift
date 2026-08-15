import Testing
@testable import Bloom

@Suite("Cycle predictor")
struct CyclePredictorTests {
    @Test("empty history falls back to 28-day average, wide + low confidence")
    func emptyHistory() {
        let p = CyclePredictor.predict(history: [])
        #expect(p.mostLikelyDay == 28)
        #expect(p.isRange)
        #expect(p.confidence <= 0.4)
    }

    @Test("a prediction is always a range, never a single certain day")
    func alwaysARange() {
        for history in [[28], [27, 29, 28], [21, 35, 28, 30]] {
            #expect(CyclePredictor.predict(history: history).isRange)
        }
    }

    @Test("regular history yields higher confidence than irregular history")
    func regularityRaisesConfidence() {
        let regular = CyclePredictor.predict(history: [28, 28, 29, 28, 27, 28])
        let irregular = CyclePredictor.predict(history: [21, 35, 24, 33, 22, 34])
        #expect(regular.confidence > irregular.confidence)
    }

    @Test("confidence stays within [0, 0.95]")
    func confidenceBounded() {
        let p = CyclePredictor.predict(history: [28, 28, 28, 28, 28, 28])
        #expect(p.confidence >= 0 && p.confidence <= 0.95)
    }

    @Test("most-likely day tracks the historical average")
    func mostLikelyTracksAverage() {
        let p = CyclePredictor.predict(history: [30, 30, 30])
        #expect(p.mostLikelyDay == 30)
    }
}
