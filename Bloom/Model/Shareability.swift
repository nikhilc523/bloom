import Foundation

/// How a piece of logged data may (or may not) ever reach the partner.
///
/// This is the type-system encoding of the privacy default matrix in
/// `docs/research/03-partner-sharing-privacy.md` §1. It exists so the privacy
/// invariants are *enforceable and testable before any persistence or UI*:
/// the partner never receives a raw diary entry — only softened interpretations
/// she chooses to give — and some categories can never cross at all.
enum Shareability: String, CaseIterable, Codable, Sendable {
    /// Shared by default, as a low-resolution *state* (e.g. "period started"),
    /// never the underlying intensity. She can still turn it off.
    case shareable

    /// Off by default. She can opt in per-item, and it is always sent *softened*
    /// (an interpretation describing his recommended behaviour), never the raw log.
    case softenedOptIn

    /// No toggle exists. Structurally cannot cross to the partner — removing the
    /// toggle removes the coercion vector (sex, contraception, weight, Private notes).
    case neverShareable

    /// A share toggle exists in the UI only when the field is not `neverShareable`.
    /// A partner can never pressure her to flip a switch that does not exist.
    var hasToggle: Bool { self != .neverShareable }

    /// Whether the field participates in sharing without an explicit opt-in.
    var isSharedByDefault: Bool { self == .shareable }

    /// Whether any value of this field could ever appear in a `SharedState`.
    var canEverReachPartner: Bool { self != .neverShareable }
}

// MARK: - Compile-time guarantee

/// Marker for field value types that *may* be promoted into the partner
/// projection (as a softened interpretation). Downstream projection code
/// (Stage 10) constrains its inputs to `SharePermitted`, so an un-shareable
/// type is rejected *at compile time*, not merely at runtime.
///
/// A value type conforms to **exactly one** of `SharePermitted` / `NeverShareable`.
protocol SharePermitted: Sendable {
    /// The declared shareability of this field. Never `.neverShareable`.
    static var shareability: Shareability { get }
}

/// Marker for field value types that can **never** reach the partner. It
/// deliberately does *not* refine `SharePermitted`, so these types are
/// un-representable anywhere a shareable value is required.
protocol NeverShareable: Sendable {}

extension NeverShareable {
    /// Un-shareable types always report `.neverShareable`.
    static var shareability: Shareability { .neverShareable }
}

/// A value that has been cleared to cross to the partner. The generic bound
/// `V: SharePermitted` is the compile-time gate: attempting to wrap an
/// un-shareable field's value type simply does not compile.
///
///     ShareableEnvelope(Energy.low)        // ✅ SharePermitted
///     ShareableEnvelope(SexActivity.none)  // ❌ does not compile — NeverShareable
struct ShareableEnvelope<V: SharePermitted>: Sendable {
    let value: V
    var shareability: Shareability { V.shareability }
    init(_ value: V) { self.value = value }
}

// MARK: - Field catalogue

/// The tier a field belongs to, controlling progressive disclosure
/// (`docs/product/01-data-model.md`: core-minimal at depth-0, advanced behind a tap).
enum FieldTier: String, CaseIterable, Codable, Sendable {
    case core
    case advanced
}

/// Every logged field in `DailyLog`, tagged with its tier and shareability.
///
/// This is the single source of truth the tests walk to prove *completeness*
/// (every field in the data-model doc exists) and *privacy* (the un-shareable
/// four have no toggle). It mirrors the value-type properties on `DailyLog`.
enum LogField: String, CaseIterable, Codable, Sendable {
    // Core
    case flow
    case crampSeverity
    case mood
    case energy
    case pms
    case sexActivity
    // Advanced
    case bloodColor
    case clotSize
    case painLocation
    case bbt
    case cervicalMucus
    case cervicalPosition
    case lhTest
    case medication
    case discharge
    case digestion
    case headache
    case cravings
    case skin
    case sleepQuality
    case weight
    case waterIntake
    case libido
    case note

    var tier: FieldTier {
        switch self {
        case .flow, .crampSeverity, .mood, .energy, .pms, .sexActivity:
            return .core
        default:
            return .advanced
        }
    }

    /// Shareability per the default matrix in `docs/research/03-partner-sharing-privacy.md` §1.
    var shareability: Shareability {
        switch self {
        // Shared by default, as state only.
        case .flow:
            return .shareable
        // No toggle exists — the four un-shareable categories.
        case .sexActivity, .medication, .weight:
            return .neverShareable
        // Note is per-note opt-in; a Private note is un-shareable & invisible.
        // The type is opt-in; the `isPrivate` gate enforces the never case at value level.
        case .note:
            return .softenedOptIn
        // Everything else: hidden by default, individually promotable / softened.
        default:
            return .softenedOptIn
        }
    }

    /// The four categories with no share affordance at all
    /// (`docs/research/03-partner-sharing-privacy.md` TL;DR §3).
    static var neverShareableFields: [LogField] {
        allCases.filter { $0.shareability == .neverShareable }
    }
}
