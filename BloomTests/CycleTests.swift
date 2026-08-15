import Testing
@testable import Bloom

@Suite("Cycle math")
struct CycleTests {
    @Test func defaultLengthIs28() {
        #expect(Cycle().lengthDays == 28)
    }

    @Test func ovulationIsLengthMinus14() {
        #expect(Cycle(lengthDays: 28).ovulationDay == 14)
        #expect(Cycle(lengthDays: 30).ovulationDay == 16)
    }

    @Test("phase boundaries for a 28-day cycle", arguments: [
        (1, CyclePhase.menstrual),
        (5, CyclePhase.menstrual),
        (8, CyclePhase.follicular),
        (14, CyclePhase.ovulation),
        (20, CyclePhase.luteal),
        (28, CyclePhase.luteal),
    ])
    func phaseForDay(_ day: Int, _ expected: CyclePhase) {
        #expect(Cycle(lengthDays: 28).phase(onDay: day) == expected)
    }

    @Test("normal length is 21...35 (ACOG)", arguments: [
        (20, false), (21, true), (28, true), (35, true), (36, false),
    ])
    func normalLength(_ length: Int, _ expected: Bool) {
        #expect(Cycle.isNormalLength(length) == expected)
    }

    @Test func noneIsNotAValidPeriodFlow() {
        #expect(Cycle.isValidPeriodFlow(.none) == false)
        #expect(Cycle.isValidPeriodFlow(.medium) == true)
    }
}
