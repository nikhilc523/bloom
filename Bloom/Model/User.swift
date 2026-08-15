import Foundation

/// The life stage that controls active fields, flag thresholds, and prediction
/// validity (`docs/product/01-data-model.md`). Switching modes changes what the
/// app tracks and how it reasons — e.g. teen widens the short/long-cycle bounds.
enum LifeStageMode: String, CaseIterable, Codable, Sendable {
    case cycle
    case ttc          // trying to conceive
    case pregnancy
    case postpartum
    case perimenopause
    case birthControl
    case teen

    /// Whether calendar-method next-period prediction is meaningful in this mode.
    /// Pregnancy suspends the cycle entirely; postpartum/perimenopause are erratic.
    var supportsCyclePrediction: Bool {
        switch self {
        case .cycle, .ttc, .birthControl, .teen: return true
        case .pregnancy, .postpartum, .perimenopause: return false
        }
    }

    /// Teen mode widens the "long cycle" bound to 45 days
    /// (`docs/product/01-data-model.md` rule thresholds).
    var maxNormalCycleLength: Int { self == .teen ? 45 : 35 }
}

/// The person who owns the data — "she is the data controller"
/// (`docs/research/03-partner-sharing-privacy.md` §0). Pure value type.
struct User: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    var displayName: String
    var birthDate: Date?
    var lifeStageMode: LifeStageMode
    var avgCycleLength: Int
    var avgPeriodLength: Int
    var onboardedAt: Date
    /// Her chosen partner-sharing preset. Defaults to Supportive, but the UI
    /// lists Minimal first so the protective option is never buried (§1 rule 1).
    var sharingPreset: SharingPreset

    init(
        id: UUID = UUID(),
        displayName: String,
        birthDate: Date? = nil,
        lifeStageMode: LifeStageMode = .cycle,
        avgCycleLength: Int = 28,
        avgPeriodLength: Int = 5,
        onboardedAt: Date,
        sharingPreset: SharingPreset = .supportive
    ) {
        self.id = id
        self.displayName = displayName
        self.birthDate = birthDate
        self.lifeStageMode = lifeStageMode
        self.avgCycleLength = max(1, avgCycleLength)
        self.avgPeriodLength = max(1, avgPeriodLength)
        self.onboardedAt = onboardedAt
        self.sharingPreset = sharingPreset
    }
}
