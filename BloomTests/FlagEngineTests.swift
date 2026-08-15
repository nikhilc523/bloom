import Foundation
import Testing
@testable import Bloom

/// Boundary tests for the clinical-flag rule engine. Every rule is exercised on
/// *both* sides of its threshold (fires at the threshold, silent just below),
/// and every produced message is checked to be a clinician nudge — never a
/// diagnosis (`docs/product/01-data-model.md` §Rule thresholds).
@Suite("Flag engine")
struct FlagEngineTests {
    // Deterministic clock + calendar (UTC so day math never hits DST).
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    let cal = FlagEngineTests.cal
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    func day(_ n: Int) -> Date { Self.cal.date(byAdding: .day, value: n, to: Date(timeIntervalSince1970: 1_700_000_000))! }

    func log(_ dayOffset: Int, flow: Flow? = nil, clot: ClotSize? = nil, sex: SexActivity? = nil) -> DailyLog {
        DailyLog(date: day(dayOffset), flow: flow, sexActivity: sex, clotSize: clot)
    }

    func cycle(start: Int, length: Int? = nil, periodLength: Int? = nil, predicted: Bool = false) -> CycleRecord {
        CycleRecord(startDate: day(start), lengthDays: length, periodLengthDays: periodLength, isPredicted: predicted)
    }

    // MARK: - Heavy bleeding

    @Test("heavy flow: 2 consecutive days fire, a single day does not")
    func heavyConsecutive() {
        let one = FlagEngine.heavyBleedingFlag(logs: [log(0, flow: .heavy)], cycles: [], asOf: day(0), calendar: cal)
        #expect(one == nil)

        let two = FlagEngine.heavyBleedingFlag(
            logs: [log(0, flow: .heavy), log(1, flow: .heavy)], cycles: [], asOf: day(1), calendar: cal
        )
        #expect(two?.type == .heavyBleeding)
    }

    @Test("heavy flow: two heavy days that are NOT consecutive do not fire")
    func heavyNonConsecutive() {
        let f = FlagEngine.heavyBleedingFlag(
            logs: [log(0, flow: .heavy), log(2, flow: .heavy)], cycles: [], asOf: day(2), calendar: cal
        )
        #expect(f == nil)
    }

    @Test("period length: 8 days fires, 7 days does not")
    func periodLengthBoundary() {
        #expect(FlagEngine.heavyBleedingFlag(logs: [], cycles: [cycle(start: 0, periodLength: 7)], asOf: day(0), calendar: cal) == nil)
        #expect(FlagEngine.heavyBleedingFlag(logs: [], cycles: [cycle(start: 0, periodLength: 8)], asOf: day(0), calendar: cal)?.type == .heavyBleeding)
    }

    @Test("clot: large (≥2.5cm) fires, small does not")
    func clotBoundary() {
        #expect(FlagEngine.heavyBleedingFlag(logs: [log(0, clot: .small)], cycles: [], asOf: day(0), calendar: cal) == nil)
        #expect(FlagEngine.heavyBleedingFlag(logs: [log(0, clot: .large)], cycles: [], asOf: day(0), calendar: cal)?.type == .heavyBleeding)
    }

    // MARK: - Irregular cycle

    @Test("irregular: spread of 7 days fires, 6 does not")
    func irregularBoundary() {
        let below = [cycle(start: 0, length: 28), cycle(start: 30, length: 34)]   // spread 6
        let at = [cycle(start: 0, length: 28), cycle(start: 30, length: 35)]      // spread 7
        #expect(FlagEngine.irregularCycleFlag(cycles: below, mode: .cycle, asOf: day(60)) == nil)
        #expect(FlagEngine.irregularCycleFlag(cycles: at, mode: .cycle, asOf: day(60))?.type == .irregularCycle)
    }

    @Test("irregular: suppressed in teen / postpartum / perimenopause")
    func irregularSuppressed() {
        let wild = [cycle(start: 0, length: 24), cycle(start: 30, length: 44)]    // spread 20
        for mode in [LifeStageMode.teen, .postpartum, .perimenopause] {
            #expect(FlagEngine.irregularCycleFlag(cycles: wild, mode: mode, asOf: day(60)) == nil)
        }
        #expect(FlagEngine.irregularCycleFlag(cycles: wild, mode: .cycle, asOf: day(60)) != nil)
    }

    // MARK: - Short / long cycle

    @Test("short cycle: 20 fires, 21 does not")
    func shortBoundary() {
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 21)], mode: .cycle, asOf: day(30)) == nil)
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 20)], mode: .cycle, asOf: day(30))?.type == .shortLongCycle)
    }

    @Test("long cycle (adult): 36 fires, 35 does not")
    func longAdultBoundary() {
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 35)], mode: .cycle, asOf: day(40)) == nil)
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 36)], mode: .cycle, asOf: day(40))?.type == .shortLongCycle)
    }

    @Test("long cycle (teen widening): 45 does not fire, 46 does")
    func longTeenBoundary() {
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 45)], mode: .teen, asOf: day(50)) == nil)
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 46)], mode: .teen, asOf: day(50))?.type == .shortLongCycle)
        // A 40-day cycle is long for an adult but normal for a teen.
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 40)], mode: .cycle, asOf: day(50))?.type == .shortLongCycle)
        #expect(FlagEngine.shortLongCycleFlag(cycles: [cycle(start: 0, length: 40)], mode: .teen, asOf: day(50)) == nil)
    }

    // MARK: - Missed period

    @Test("missed: 90 days fires, 89 does not, and prompts a pregnancy test first")
    func missedBoundary() {
        let cycles = [cycle(start: 0)]
        #expect(FlagEngine.missedPeriodFlag(cycles: cycles, mode: .cycle, asOf: day(89), calendar: cal) == nil)
        let f = FlagEngine.missedPeriodFlag(cycles: cycles, mode: .cycle, asOf: day(90), calendar: cal)
        #expect(f?.type == .missedPeriod)
        #expect(f?.message.lowercased().contains("pregnancy test") == true)
    }

    @Test("missed: not applicable in pregnancy / postpartum")
    func missedSuppressed() {
        let cycles = [cycle(start: 0)]
        #expect(FlagEngine.missedPeriodFlag(cycles: cycles, mode: .pregnancy, asOf: day(200), calendar: cal) == nil)
        #expect(FlagEngine.missedPeriodFlag(cycles: cycles, mode: .postpartum, asOf: day(200), calendar: cal) == nil)
    }

    // MARK: - Urgent

    @Test("urgent: bleeding + dizziness fires; bleeding alone (no acute symptom) does not")
    func urgentDizziness() {
        let logs = [log(0, flow: .medium)]
        #expect(FlagEngine.urgentFlags(logs: logs, cycles: [], mode: .cycle, asOf: day(0), acute: AcuteSymptoms(), calendar: cal).isEmpty)
        let flags = FlagEngine.urgentFlags(logs: logs, cycles: [], mode: .cycle, asOf: day(0), acute: AcuteSymptoms(dizziness: true), calendar: cal)
        #expect(flags.contains { $0.triggeredByRule == "urgent:bleeding+dizziness" })
        #expect(flags.allSatisfy { $0.severity == .urgent })
    }

    @Test("urgent: shortness of breath with bleeding fires; without bleeding it does not")
    func urgentShortnessOfBreath() {
        let noBleed = FlagEngine.urgentFlags(logs: [log(0, flow: .none)], cycles: [], mode: .cycle, asOf: day(0), acute: AcuteSymptoms(shortnessOfBreath: true), calendar: cal)
        #expect(noBleed.isEmpty)
        let bleed = FlagEngine.urgentFlags(logs: [log(0, flow: .spotting)], cycles: [], mode: .cycle, asOf: day(0), acute: AcuteSymptoms(shortnessOfBreath: true), calendar: cal)
        #expect(bleed.contains { $0.triggeredByRule == "urgent:bleeding+shortnessOfBreath" })
    }

    @Test("urgent: post-coital bleeding fires only when bleeding AND sex are on the same day")
    func urgentPostCoital() {
        // Bleeding, no sex logged → no post-coital flag.
        #expect(!FlagEngine.urgentFlags(logs: [log(0, flow: .spotting)], cycles: [], mode: .cycle, asOf: day(0), calendar: cal)
            .contains { $0.triggeredByRule == "urgent:postCoital" })
        // Sex logged, no bleeding → no post-coital flag.
        #expect(!FlagEngine.urgentFlags(logs: [log(0, flow: .none, sex: .protected)], cycles: [], mode: .cycle, asOf: day(0), calendar: cal)
            .contains { $0.triggeredByRule == "urgent:postCoital" })
        // Both → fires.
        #expect(FlagEngine.urgentFlags(logs: [log(0, flow: .spotting, sex: .protected)], cycles: [], mode: .cycle, asOf: day(0), calendar: cal)
            .contains { $0.triggeredByRule == "urgent:postCoital" })
    }

    @Test("urgent: inter-menstrual bleeding — day 8 fires, day 7 does not")
    func urgentInterMenstrual() {
        let c = [cycle(start: 0, length: 28)]
        // offset = dayOffset + 1, so day-7 offset = 8 (fires), day-6 offset = 7 (does not).
        let below = FlagEngine.urgentFlags(logs: [log(6, flow: .spotting)], cycles: c, mode: .cycle, asOf: day(6), calendar: cal)
        #expect(!below.contains { $0.triggeredByRule == "urgent:interMenstrual" })
        let at = FlagEngine.urgentFlags(logs: [log(7, flow: .spotting)], cycles: c, mode: .cycle, asOf: day(7), calendar: cal)
        #expect(at.contains { $0.triggeredByRule == "urgent:interMenstrual" })
    }

    @Test("urgent: post-menopausal bleeding — 365-day gap fires, 364 does not (perimenopause)")
    func urgentPostMenopausal() {
        let c = [cycle(start: 0)]
        let below = FlagEngine.urgentFlags(logs: [log(364, flow: .spotting)], cycles: c, mode: .perimenopause, asOf: day(364), calendar: cal)
        #expect(!below.contains { $0.triggeredByRule == "urgent:postMenopausal" })
        let at = FlagEngine.urgentFlags(logs: [log(365, flow: .spotting)], cycles: c, mode: .perimenopause, asOf: day(365), calendar: cal)
        #expect(at.contains { $0.triggeredByRule == "urgent:postMenopausal" })
        // Same gap but not perimenopause → no post-menopausal flag.
        let wrongMode = FlagEngine.urgentFlags(logs: [log(365, flow: .spotting)], cycles: c, mode: .cycle, asOf: day(365), calendar: cal)
        #expect(!wrongMode.contains { $0.triggeredByRule == "urgent:postMenopausal" })
    }

    // MARK: - Cross-cutting guarantees

    @Test("every produced flag ends in the clinician nudge and never diagnoses")
    func noDiagnosisLanguage() {
        let logs = [log(0, flow: .heavy, sex: .protected), log(1, flow: .heavy)]
        let cycles = [cycle(start: 0, length: 40, periodLength: 9)]
        let flags = FlagEngine.evaluate(
            cycles: cycles, logs: logs, mode: .cycle, asOf: day(120),
            acute: AcuteSymptoms(dizziness: true), calendar: cal
        )
        #expect(!flags.isEmpty)
        let bannedWords = ["you have", "diagnosis", "diagnosed", "you are suffering", "confirmed"]
        for f in flags {
            #expect(f.message.hasSuffix(ClinicalFlag.clinicianSuffix))
            let lower = f.message.lowercased()
            for word in bannedWords { #expect(!lower.contains(word)) }
        }
    }

    @Test("evaluate orders the most severe flag first")
    func severityOrdering() {
        // An urgent (post-coital) alongside a merely informational short-cycle.
        let logs = [log(0, flow: .spotting, sex: .protected)]
        let cycles = [cycle(start: 0, length: 20)]
        let flags = FlagEngine.evaluate(cycles: cycles, logs: logs, mode: .cycle, asOf: day(30), calendar: cal)
        #expect(flags.first?.severity == .urgent)
        #expect(flags.contains { $0.type == .shortLongCycle })
    }

    @Test("no data → no flags")
    func emptyProducesNothing() {
        #expect(FlagEngine.evaluate(cycles: [], logs: [], mode: .cycle, asOf: day(0), calendar: cal).isEmpty)
    }

    @Test("predicted cycles are ignored by the rules")
    func predictedCyclesIgnored() {
        // A predicted 40-day cycle must not trip the long-cycle rule.
        let cycles = [cycle(start: 0, length: 40, predicted: true)]
        #expect(FlagEngine.shortLongCycleFlag(cycles: cycles, mode: .cycle, asOf: day(40)) == nil)
    }
}
