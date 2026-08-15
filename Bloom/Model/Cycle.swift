import Foundation

/// The four menstrual cycle phases (docs/research/01-clinical-science.md §1).
enum CyclePhase: String, Sendable {
    case menstrual, follicular, ovulation, luteal

    var label: String { rawValue.capitalized }
}

/// Pure, testable cycle math. No storage/UI concerns — kept deliberately simple
/// so it is trivially unit-testable (see BloomTests/CycleTests.swift).
struct Cycle: Equatable, Sendable {
    /// Total length of the cycle in days (Day 1 = first day of bleeding).
    let lengthDays: Int

    init(lengthDays: Int = 28) {
        self.lengthDays = max(1, lengthDays)
    }

    /// Estimated ovulation day. Luteal phase is ~14 days, so ovulation is
    /// length − 14 (never a single certainty in reality — see the predictor).
    var ovulationDay: Int {
        max(1, lengthDays - 14)
    }

    /// Phase for a given cycle day (1-based).
    func phase(onDay day: Int) -> CyclePhase {
        let d = min(max(day, 1), lengthDays)
        switch d {
        case 1...5: return .menstrual
        case 6..<ovulationDay: return .follicular
        case ovulationDay...(ovulationDay + 1): return .ovulation
        default: return .luteal
        }
    }

    /// Adult "normal" cycle length is 21–35 days (ACOG). Used by the flag engine.
    static func isNormalLength(_ length: Int) -> Bool {
        (21...35).contains(length)
    }

    /// A flow value is valid to log if it is a real intensity (not `.none` as a period entry).
    static func isValidPeriodFlow(_ flow: Flow) -> Bool {
        flow != .none
    }
}
