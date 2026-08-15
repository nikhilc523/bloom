import Foundation

/// The three onboarding presets she can fully override
/// (`docs/research/03-partner-sharing-privacy.md` §1 rule 1). Default is
/// `supportive`, but the UI lists `minimal` first so the protective option is
/// never buried.
enum SharingPreset: String, CaseIterable, Codable, Sendable {
    /// Phase + "period started" only.
    case minimal
    /// Adds gentle-window + next-period window. The default.
    case supportive
    /// Adds the fertile window — only meaningful when both partners are in TTC mode.
    case ttc
}

/// A partner link (`docs/product/01-data-model.md`). She is the controller; he is
/// a guest. Un-shareable fields are absent from `fieldOverrides` by construction:
/// only `hasToggle` fields can be keyed, so there is no switch to pressure.
struct PartnerLink: Equatable, Codable, Sendable, Identifiable {
    enum Status: String, CaseIterable, Codable, Sendable {
        case active
        case revoked
    }

    let id: UUID
    var partnerName: String
    let linkedAt: Date
    var sharingPreset: SharingPreset
    /// Per-item overrides on top of the preset. Keyed only by fields that have a
    /// toggle — un-shareable fields can never be added (enforced in `init`).
    private(set) var fieldOverrides: [LogField: Bool]
    var status: Status

    init(
        id: UUID = UUID(),
        partnerName: String,
        linkedAt: Date,
        sharingPreset: SharingPreset = .supportive,
        fieldOverrides: [LogField: Bool] = [:],
        status: Status = .active
    ) {
        self.id = id
        self.partnerName = partnerName
        self.linkedAt = linkedAt
        self.sharingPreset = sharingPreset
        // Drop any override for a field with no toggle — the switch does not exist.
        self.fieldOverrides = fieldOverrides.filter { $0.key.shareability.hasToggle }
        self.status = status
    }

    /// Sets a per-item override. A no-op for un-shareable fields — there is no
    /// toggle to flip, so a partner can never pressure her to flip it.
    mutating func setOverride(_ field: LogField, shared: Bool) {
        guard field.shareability.hasToggle else { return }
        fieldOverrides[field] = shared
    }
}

/// The mood/energy "weather" — one emoji + one word, and only after she confirms
/// it (`docs/research/03` §1). Mood is the most weaponizable field, so it is never
/// auto-broadcast: `isConfirmed` gates whether it may cross at all.
struct MoodWeather: Equatable, Codable, Sendable {
    let emoji: String
    let word: String
    /// She confirmed this specific weather before it could send. If false, it
    /// must not appear in the partner projection.
    let isConfirmed: Bool

    init(emoji: String, word: String, isConfirmed: Bool = false) {
        self.emoji = emoji
        self.word = word
        self.isConfirmed = isConfirmed
    }
}

/// The ONLY thing that crosses to the partner — interpretations, not logs
/// (`docs/product/01-data-model.md`). Carries no raw `DailyLog` field, keeps no
/// history on his side, and a hidden item is indistinguishable from an un-logged
/// one (every field is optional, so "nothing" reads identically either way).
struct SharedState: Equatable, Codable, Sendable {
    /// Plain-language current phase, e.g. "luteal phase". Low-sensitivity framing.
    var currentPhaseLabel: String?
    /// State only — "period likely started" — never flow/heaviness.
    var periodStartedFlag: Bool
    /// A *window* ("~in 4–6 days"), never a hard date — windows resist surveillance.
    var nextPeriodWindow: PredictionWindow?
    /// The care payload: "gentle window this week", softened.
    var gentleWindowActive: Bool
    /// Present only if she confirmed it (`MoodWeather.isConfirmed`). `private(set)`
    /// so the consent gate can't be bypassed by direct assignment — use
    /// `setMoodWeather(_:)`, which drops anything unconfirmed.
    private(set) var moodWeather: MoodWeather?
    /// Shared only in TTC mode, and only if both are in TTC mode.
    var fertileWindow: FertileWindow?

    init(
        currentPhaseLabel: String? = nil,
        periodStartedFlag: Bool = false,
        nextPeriodWindow: PredictionWindow? = nil,
        gentleWindowActive: Bool = false,
        moodWeather: MoodWeather? = nil,
        fertileWindow: FertileWindow? = nil
    ) {
        self.currentPhaseLabel = currentPhaseLabel
        self.periodStartedFlag = periodStartedFlag
        self.nextPeriodWindow = nextPeriodWindow
        self.gentleWindowActive = gentleWindowActive
        // A mood weather only crosses once she has confirmed it.
        self.moodWeather = (moodWeather?.isConfirmed == true) ? moodWeather : nil
        self.fertileWindow = fertileWindow
    }

    /// Sets the mood weather, enforcing the consent gate: anything unconfirmed is
    /// dropped, so mood — the most weaponizable field — can never auto-broadcast.
    mutating func setMoodWeather(_ weather: MoodWeather?) {
        moodWeather = (weather?.isConfirmed == true) ? weather : nil
    }

    /// The blank state a revoked/disconnected partner sees — no residue, no signal
    /// that anything was ever hidden (`docs/research/03` §4 cardinal rule).
    static let blank = SharedState()
}

/// A floating pinned note — a fridge magnet, not a chat log
/// (`docs/research/03` §3). One active pin per person; no edit after delivery;
/// no read receipts; the recipient can silently mute.
struct PinnedNote: Equatable, Codable, Sendable, Identifiable {
    enum Kind: String, CaseIterable, Codable, Sendable {
        case love       // 💛 "thinking of you"
        case reminder   // ⏰ "take your iron"
        case highlight  // ✨ her voice: "rough day", "I'd love flowers this week"
    }

    /// Length cap — a note, not an essay (`docs/research/03` §3 tone-safe composing).
    static let maxLength = 280

    let id: UUID
    let authorId: UUID
    let type: Kind
    let text: String
    let createdAt: Date
    var deliveredAt: Date?
    /// The recipient muted this pin — silently, with no signal to the author.
    var mutedByRecipient: Bool

    init(
        id: UUID = UUID(),
        authorId: UUID,
        type: Kind,
        text: String,
        createdAt: Date,
        deliveredAt: Date? = nil,
        mutedByRecipient: Bool = false
    ) {
        self.id = id
        self.authorId = authorId
        self.type = type
        self.text = String(text.prefix(Self.maxLength))
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.mutedByRecipient = mutedByRecipient
    }
}
