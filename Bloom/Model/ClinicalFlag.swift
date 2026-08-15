import Foundation

/// The categories of clinical flag the rule engine (Stage 2) can raise
/// (`docs/product/01-data-model.md` §ClinicalFlag → `docs/research/01` §3).
/// A flag is never a diagnosis — always a gentle "worth discussing" nudge.
enum FlagType: String, CaseIterable, Codable, Sendable {
    case heavyBleeding
    case irregularCycle
    case shortLongCycle
    case missedPeriod
    case possiblePCOS
    case possibleEndometriosis
    case possibleThyroid
    case pregnancySignal
    case urgent
}

/// How prominently a flag surfaces. `urgent` maps to the escalation cases
/// (bleeding with dizziness/SOB, post-coital, post-menopausal).
enum FlagSeverity: String, CaseIterable, Codable, Sendable, Comparable {
    case informational
    case attention
    case urgent

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}

/// A raised clinical flag (`docs/product/01-data-model.md`). Pure value type;
/// the rule engine that produces these is Stage 2.
struct ClinicalFlag: Equatable, Codable, Sendable, Identifiable {
    /// Every flag message ends with this — never a diagnosis, always a nudge
    /// toward a clinician (`docs/product/01-data-model.md` §ClinicalFlag).
    static let clinicianSuffix = "…may be worth discussing with a clinician."

    let id: UUID
    let type: FlagType
    /// Identifier of the rule that fired (e.g. "period>7d") — for auditability.
    let triggeredByRule: String
    let severity: FlagSeverity
    let message: String
    let createdAt: Date
    var dismissed: Bool

    /// Builds a flag, guaranteeing the message ends in the clinician suffix. A
    /// caller cannot construct a flag whose copy reads as a diagnosis instead of
    /// a nudge — the suffix is appended if missing.
    init(
        id: UUID = UUID(),
        type: FlagType,
        triggeredByRule: String,
        severity: FlagSeverity,
        message: String,
        createdAt: Date,
        dismissed: Bool = false
    ) {
        self.id = id
        self.type = type
        self.triggeredByRule = triggeredByRule
        self.severity = severity
        self.message = Self.ensuringClinicianSuffix(message)
        self.createdAt = createdAt
        self.dismissed = dismissed
    }

    /// Whether a message already carries the clinician nudge (never a diagnosis).
    static func isClinicianSafe(_ message: String) -> Bool {
        message.hasSuffix(clinicianSuffix)
    }

    /// Appends the clinician suffix unless already present, trimming any trailing
    /// sentence punctuation/whitespace first so the join reads naturally.
    static func ensuringClinicianSuffix(_ message: String) -> String {
        guard !isClinicianSafe(message) else { return message }
        let trimmed = message.trimmingCharacters(in: CharacterSet(charactersIn: " .…"))
        return trimmed.isEmpty ? clinicianSuffix : "\(trimmed) \(clinicianSuffix)"
    }
}
