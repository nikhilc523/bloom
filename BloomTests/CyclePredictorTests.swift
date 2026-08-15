import Foundation
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

    @Test("a perfectly regular history gives a tight (±1) band")
    func regularHistoryTightBand() {
        let p = CyclePredictor.predict(history: [28, 28, 28, 28])
        #expect(p.bandWidthDays == 2)        // ±1 around the mean
        #expect(p.earliestDay == 27 && p.latestDay == 29)
    }

    @Test("an irregular history widens the band")
    func irregularHistoryWidensBand() {
        let regular = CyclePredictor.predict(history: [28, 28, 28])
        let irregular = CyclePredictor.predict(history: [21, 35, 28])
        #expect(irregular.bandWidthDays > regular.bandWidthDays)
    }

    @Test("more data raises confidence for equally-regular histories")
    func dataWeightRaisesConfidence() {
        let sparse = CyclePredictor.predict(history: [28, 28])
        let rich = CyclePredictor.predict(history: [28, 28, 28, 28, 28, 28])
        #expect(rich.confidence > sparse.confidence)
    }

    @Test("a prediction always requires ghost styling — never a certainty")
    func alwaysGhostStyled() {
        #expect(CyclePredictor.predict(history: []).requiresGhostStyling)
        #expect(CyclePredictor.predict(history: [28, 30, 27]).requiresGhostStyling)
    }

    // MARK: - Dated prediction

    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    @Test("nextPeriodPrediction maps the day-band onto real dates")
    func datedPredictionWindow() {
        let cal = Self.cal
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let now = start
        let prediction = CyclePredictor.nextPeriodPrediction(
            lastPeriodStart: start, history: [28, 28, 28], mode: .cycle, generatedAt: now, calendar: cal
        )
        let window = try! #require(prediction).nextPeriod
        // Regular history → ±1 around day 28.
        #expect(cal.dateComponents([.day], from: start, to: window.windowStart).day == 27)
        #expect(cal.dateComponents([.day], from: start, to: window.windowEnd).day == 29)
        #expect(window.confidence > 0 && window.confidence <= 0.95)
    }

    @Test("nextPeriodPrediction is nil for life stages without calendar prediction")
    func noPredictionForUnsupportedModes() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for mode in [LifeStageMode.pregnancy, .postpartum, .perimenopause] {
            #expect(CyclePredictor.nextPeriodPrediction(
                lastPeriodStart: start, history: [28, 28], mode: mode, generatedAt: start, calendar: Self.cal
            ) == nil)
        }
    }
}
