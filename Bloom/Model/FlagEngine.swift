import Foundation

// MARK: - Flow helpers used by the rules

extension Flow {
    /// Any real bleeding (spotting → heavy). `.none` is not bleeding.
    var isBleeding: Bool { self != .none }
    /// The heaviest intensity — feeds the menorrhagia (heavy-bleeding) rule.
    var isHeavy: Bool { self == .heavy }
}

/// Acute red-flag symptoms the daily log doesn't track as first-class fields but
/// that the urgent rules need (`docs/research/01` §3 "Urgent"). Passed in by the
/// caller (e.g. from an Ask-Bloom triage turn); empty by default so the rules
/// stay silent unless the symptom is actually reported.
struct AcuteSymptoms: Equatable, Sendable {
    var dizziness: Bool
    var shortnessOfBreath: Bool

    init(dizziness: Bool = false, shortnessOfBreath: Bool = false) {
        self.dizziness = dizziness
        self.shortnessOfBreath = shortnessOfBreath
    }

    var isEmpty: Bool { !dizziness && !shortnessOfBreath }
}

/// Pure, deterministic clinical-flag rule engine (`docs/product/01-data-model.md`
/// §Rule thresholds → `docs/research/01` §3). Operates over `[CycleRecord]` /
/// `[DailyLog]`; no persistence, UI, or AI phrasing (that is Stage 8).
///
/// **A flag is never a diagnosis.** Every message is built through
/// `ClinicalFlag`, which guarantees the "…may be worth discussing with a
/// clinician" suffix. The engine only *surfaces* patterns and routes to a human.
enum FlagEngine {
    // MARK: Thresholds (documented, sourced from `docs/research/01` §3)

    /// Heavy flow on this many consecutive days reads as heavy bleeding.
    static let heavyFlowConsecutiveDays = 2
    /// A period lasting longer than this many days (menorrhagia signal).
    static let maxPeriodDays = 7
    /// Cycle-to-cycle drift at/above this many days reads as irregular.
    static let irregularShiftDays = 7
    /// Adult cycles shorter than this are "short".
    static let shortCycleMinDays = 21
    /// No period for at least this many days → missed (pregnancy-test-first).
    static let missedPeriodDays = 90
    /// Bleeding resuming after a gap this long (perimenopause) is treated as
    /// post-menopausal bleeding — always warrants evaluation.
    static let postMenopausalGapDays = 365
    /// Earliest cycle day (1-based) at which bleeding counts as inter-menstrual
    /// rather than part of the period itself.
    static let interMenstrualEarliestDay = 8
    /// Buffer before the next expected period; bleeding inside it isn't flagged
    /// as inter-menstrual (it may just be an early period).
    static let premenstrualBufferDays = 3

    // MARK: - Top-level evaluation

    /// Run every rule and return the flags that fire, most-severe first.
    /// - Parameters:
    ///   - asOf: the reference "now" — passed in so the engine stays pure and
    ///     deterministic (never reads the wall clock). Used as each flag's
    ///     `createdAt` and for "days since last period".
    static func evaluate(
        cycles: [CycleRecord],
        logs: [DailyLog],
        mode: LifeStageMode = .cycle,
        asOf: Date,
        acute: AcuteSymptoms = AcuteSymptoms(),
        calendar: Calendar = .current
    ) -> [ClinicalFlag] {
        var flags: [ClinicalFlag] = []
        flags.append(contentsOf: urgentFlags(logs: logs, cycles: cycles, mode: mode, asOf: asOf, acute: acute, calendar: calendar))
        if let f = heavyBleedingFlag(logs: logs, cycles: cycles, asOf: asOf, calendar: calendar) { flags.append(f) }
        if let f = irregularCycleFlag(cycles: cycles, mode: mode, asOf: asOf) { flags.append(f) }
        if let f = shortLongCycleFlag(cycles: cycles, mode: mode, asOf: asOf) { flags.append(f) }
        if let f = missedPeriodFlag(cycles: cycles, mode: mode, asOf: asOf, calendar: calendar) { flags.append(f) }
        // Most-severe first, preserving insertion order within a severity.
        return flags.enumerated()
            .sorted { ($0.element.severity, $1.offset) > ($1.element.severity, $0.offset) }
            .map(\.element)
    }

    // MARK: - Heavy bleeding

    /// Fires on any of: heavy flow on ≥ `heavyFlowConsecutiveDays` consecutive
    /// days, a period longer than `maxPeriodDays`, or a clot ≥ 2.5 cm (`.large`).
    static func heavyBleedingFlag(
        logs: [DailyLog],
        cycles: [CycleRecord],
        asOf: Date,
        calendar: Calendar = .current
    ) -> ClinicalFlag? {
        let rule: String
        if maxConsecutiveHeavyRun(in: logs, calendar: calendar) >= heavyFlowConsecutiveDays {
            rule = "heavy:consecutive>=\(heavyFlowConsecutiveDays)d"
        } else if cycles.contains(where: { !$0.isPredicted && ($0.periodLengthDays ?? 0) > maxPeriodDays }) {
            rule = "heavy:period>\(maxPeriodDays)d"
        } else if logs.contains(where: { $0.clotSize == .large }) {
            rule = "heavy:clot>=2.5cm"
        } else {
            return nil
        }
        return flag(
            .heavyBleeding, rule, .attention,
            "Your recent bleeding looks heavier or longer than the typical range, which",
            at: asOf
        )
    }

    /// Longest run of consecutive calendar days logged with heavy flow.
    private static func maxConsecutiveHeavyRun(in logs: [DailyLog], calendar: Calendar) -> Int {
        let heavyDays = logs
            .filter { ($0.flow?.isHeavy ?? false) }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard let first = heavyDays.first else { return 0 }

        var best = 1
        var run = 1
        var prev = first
        for day in heavyDays.dropFirst() {
            let gap = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else if gap != 0 {   // gap == 0 → same day duplicate, ignore
                run = 1
            }
            prev = day
        }
        return best
    }

    // MARK: - Irregular cycles

    /// Fires when recent completed cycle lengths drift by ≥ `irregularShiftDays`.
    /// Suppressed in life stages where irregularity is expected and not a concern
    /// (teen, postpartum, perimenopause — `docs/research/01` §5).
    static func irregularCycleFlag(
        cycles: [CycleRecord],
        mode: LifeStageMode,
        asOf: Date
    ) -> ClinicalFlag? {
        guard !expectsIrregularCycles(mode) else { return nil }
        let lengths = recentCompletedLengths(cycles)
        guard lengths.count >= 2, let lo = lengths.min(), let hi = lengths.max() else { return nil }
        guard (hi - lo) >= irregularShiftDays else { return nil }
        return flag(
            .irregularCycle, "irregular:shift>=\(irregularShiftDays)d", .attention,
            "Your cycle length has been shifting more than usual, which",
            at: asOf
        )
    }

    // MARK: - Short / long cycles

    /// Fires when the most recent completed cycle is < `shortCycleMinDays` or
    /// longer than the mode's max normal length (35 adult, 45 teen).
    static func shortLongCycleFlag(
        cycles: [CycleRecord],
        mode: LifeStageMode,
        asOf: Date
    ) -> ClinicalFlag? {
        guard let length = recentCompletedLengths(cycles).last else { return nil }
        let maxNormal = mode.maxNormalCycleLength
        if length < shortCycleMinDays {
            return flag(
                .shortLongCycle, "cycle:short<\(shortCycleMinDays)d", .informational,
                "Your latest cycle was shorter than the typical range, which",
                at: asOf
            )
        }
        if length > maxNormal {
            return flag(
                .shortLongCycle, "cycle:long>\(maxNormal)d", .informational,
                "Your latest cycle was longer than the typical range, which",
                at: asOf
            )
        }
        return nil
    }

    // MARK: - Missed period

    /// Fires when it has been ≥ `missedPeriodDays` since the last logged period.
    /// The copy prompts a pregnancy test *first* (`docs/research/01` §3). Not
    /// applicable to pregnancy/postpartum, where absent periods are expected.
    static func missedPeriodFlag(
        cycles: [CycleRecord],
        mode: LifeStageMode,
        asOf: Date,
        calendar: Calendar = .current
    ) -> ClinicalFlag? {
        switch mode {
        case .pregnancy, .postpartum: return nil
        default: break
        }
        guard let lastStart = lastPeriodStart(cycles) else { return nil }
        let daysSince = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastStart),
            to: calendar.startOfDay(for: asOf)
        ).day ?? 0
        guard daysSince >= missedPeriodDays else { return nil }
        return flag(
            .missedPeriod, "missed:>=\(missedPeriodDays)d", .attention,
            "It's been \(daysSince) days since your last logged period — consider taking a pregnancy test first, and either way this",
            at: asOf
        )
    }

    // MARK: - Urgent

    /// The escalation rules (`docs/research/01` §3 "Urgent"): bleeding with
    /// dizziness/shortness of breath, post-coital bleeding, inter-menstrual
    /// bleeding, and post-menopausal bleeding. Each fires at most once.
    static func urgentFlags(
        logs: [DailyLog],
        cycles: [CycleRecord],
        mode: LifeStageMode,
        asOf: Date,
        acute: AcuteSymptoms = AcuteSymptoms(),
        calendar: Calendar = .current
    ) -> [ClinicalFlag] {
        var out: [ClinicalFlag] = []
        let hasBleeding = logs.contains { $0.flow?.isBleeding ?? false }

        // Bleeding + dizziness / shortness of breath (possible anemia).
        if hasBleeding && !acute.isEmpty {
            let rule = acute.dizziness ? "urgent:bleeding+dizziness" : "urgent:bleeding+shortnessOfBreath"
            out.append(flag(
                .urgent, rule, .urgent,
                "Bleeding along with feeling dizzy or short of breath is something that",
                at: asOf
            ))
        }

        // Post-coital bleeding — bleeding on a day sexual activity was logged.
        if logs.contains(where: { ($0.flow?.isBleeding ?? false) && ($0.sexActivity.map { $0 != .none } ?? false) }) {
            out.append(flag(
                .urgent, "urgent:postCoital", .urgent,
                "Bleeding after sex is something that",
                at: asOf
            ))
        }

        // Inter-menstrual bleeding — bleeding clearly between periods.
        if hasInterMenstrualBleeding(logs: logs, cycles: cycles, mode: mode, calendar: calendar) {
            out.append(flag(
                .urgent, "urgent:interMenstrual", .urgent,
                "Bleeding between your periods is something that",
                at: asOf
            ))
        }

        // Post-menopausal bleeding — bleeding resuming after a long gap in
        // perimenopause.
        if mode == .perimenopause,
           hasPostMenopausalBleeding(logs: logs, cycles: cycles, calendar: calendar) {
            out.append(flag(
                .urgent, "urgent:postMenopausal", .urgent,
                "Bleeding after a long gap around menopause is something that",
                at: asOf
            ))
        }

        return out
    }

    // MARK: - Rule helpers

    private static func hasInterMenstrualBleeding(
        logs: [DailyLog],
        cycles: [CycleRecord],
        mode: LifeStageMode,
        calendar: Calendar
    ) -> Bool {
        let starts = sortedRealCycles(cycles)
        guard !starts.isEmpty else { return false }

        for log in logs where (log.flow?.isBleeding ?? false) {
            let logDay = calendar.startOfDay(for: log.date)
            // The cycle this bleeding falls in: latest start on/before the log day.
            guard let idx = starts.lastIndex(where: {
                calendar.startOfDay(for: $0.startDate) <= logDay
            }) else { continue }
            let cycle = starts[idx]
            let cycleStart = calendar.startOfDay(for: cycle.startDate)
            let offset = (calendar.dateComponents([.day], from: cycleStart, to: logDay).day ?? 0) + 1 // 1-based

            // Upper bound: the next period's start (or the cycle's own length).
            let cycleLength: Int
            if idx + 1 < starts.count {
                cycleLength = calendar.dateComponents(
                    [.day],
                    from: cycleStart,
                    to: calendar.startOfDay(for: starts[idx + 1].startDate)
                ).day ?? cycle.lengthDays ?? mode.maxNormalCycleLength
            } else {
                cycleLength = cycle.lengthDays ?? mode.maxNormalCycleLength
            }

            if offset >= interMenstrualEarliestDay && offset <= (cycleLength - premenstrualBufferDays) {
                return true
            }
        }
        return false
    }

    private static func hasPostMenopausalBleeding(
        logs: [DailyLog],
        cycles: [CycleRecord],
        calendar: Calendar
    ) -> Bool {
        let starts = sortedRealCycles(cycles).map { calendar.startOfDay(for: $0.startDate) }
        for log in logs where (log.flow?.isBleeding ?? false) {
            let logDay = calendar.startOfDay(for: log.date)
            // Most recent period start strictly before this bleeding day.
            guard let priorStart = starts.last(where: { $0 < logDay }) else { continue }
            let gap = calendar.dateComponents([.day], from: priorStart, to: logDay).day ?? 0
            if gap >= postMenopausalGapDays { return true }
        }
        return false
    }

    /// Completed (non-predicted) cycles that have a recorded length, most recent
    /// last, capped to the last 6 for the irregularity window.
    private static func recentCompletedLengths(_ cycles: [CycleRecord]) -> [Int] {
        let lengths = sortedRealCycles(cycles).compactMap(\.lengthDays)
        return Array(lengths.suffix(6))
    }

    private static func lastPeriodStart(_ cycles: [CycleRecord]) -> Date? {
        sortedRealCycles(cycles).last?.startDate
    }

    private static func sortedRealCycles(_ cycles: [CycleRecord]) -> [CycleRecord] {
        cycles.filter { !$0.isPredicted }.sorted { $0.startDate < $1.startDate }
    }

    /// Life stages where cycle irregularity is expected and shouldn't be flagged.
    private static func expectsIrregularCycles(_ mode: LifeStageMode) -> Bool {
        switch mode {
        case .teen, .postpartum, .perimenopause: return true
        default: return false
        }
    }

    /// `createdAt` is always the caller-supplied `asOf`, keeping the engine pure
    /// and deterministic (it never reads the wall clock).
    private static func flag(
        _ type: FlagType,
        _ rule: String,
        _ severity: FlagSeverity,
        _ message: String,
        at date: Date
    ) -> ClinicalFlag {
        ClinicalFlag(type: type, triggeredByRule: rule, severity: severity, message: message, createdAt: date)
    }
}
