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

// MARK: - Cycle entity (persisted record)

/// An estimated ovulation day, always carried *with* its confidence — never
/// render one without the other (`docs/product/01-data-model.md`).
struct OvulationEstimate: Equatable, Codable, Sendable {
    let date: Date
    let confidence: Double   // 0...1

    init(date: Date, confidence: Double) {
        self.date = date
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// The fertile window as a range + confidence. Predicted days render ghost/dashed.
struct FertileWindow: Equatable, Codable, Sendable {
    let start: Date
    let end: Date
    let confidence: Double   // 0...1

    init(start: Date, end: Date, confidence: Double) {
        self.start = start
        self.end = end
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// The full `Cycle` entity from `docs/product/01-data-model.md` — derived and
/// editable, one per menstrual cycle. Distinct from the lightweight `Cycle`
/// math helper above (which the predictor/UI use for phase arithmetic); this is
/// the persistable record the store will map to a `@Model` in Stage 3.
struct CycleRecord: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var lengthDays: Int?
    var periodLengthDays: Int?
    var ovulationEstimate: OvulationEstimate?
    var fertileWindow: FertileWindow?
    /// Predicted cycles render as ghost/dashed and never as certainties.
    var isPredicted: Bool

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        lengthDays: Int? = nil,
        periodLengthDays: Int? = nil,
        ovulationEstimate: OvulationEstimate? = nil,
        fertileWindow: FertileWindow? = nil,
        isPredicted: Bool = false
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.lengthDays = lengthDays
        self.periodLengthDays = periodLengthDays
        self.ovulationEstimate = ovulationEstimate
        self.fertileWindow = fertileWindow
        self.isPredicted = isPredicted
    }
}
