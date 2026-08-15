import Foundation

// MARK: - Core field enums
// `Flow` lives in Flow.swift (the earliest scaffold field).

/// Subjective cramp intensity on a 0–10 scale (`docs/product/01-data-model.md`).
/// Feeds a *derived* partner cue only — the raw number is never shared.
struct CrampSeverity: Equatable, Codable, Sendable, SharePermitted {
    static let range = 0...10
    let value: Int

    /// Clamps into 0...10 so an out-of-range value is un-representable.
    init(_ value: Int) {
        self.value = min(max(value, Self.range.lowerBound), Self.range.upperBound)
    }

    static var shareability: Shareability { .softenedOptIn }
}

/// Emotional weather. Multi-select; stored as a `Set<Mood>` on the log.
/// Opt-in and softened before it can ever reach the partner (§2 mood guardrails).
enum Mood: String, CaseIterable, Codable, Sendable, SharePermitted {
    case calm, happy, irritable, anxious, low, sensitive

    static var shareability: Shareability { .softenedOptIn }
}

/// Energy level. Opt-in, softened (`docs/research/03` default matrix).
enum Energy: String, CaseIterable, Codable, Sendable, SharePermitted {
    case low, normal, high

    static var shareability: Shareability { .softenedOptIn }
}

/// Premenstrual symptoms. Multi-select; stored as a `Set<PMSSymptom>`.
enum PMSSymptom: String, CaseIterable, Codable, Sendable, SharePermitted {
    case bloating, breastTenderness, headache, cravings

    static var shareability: Shareability { .softenedOptIn }
}

/// Sexual activity. **Un-shareable** — no supportive reason a partner needs the
/// log, and the toggle's absence removes the coercion vector (`docs/research/03` §1).
enum SexActivity: String, CaseIterable, Codable, Sendable, NeverShareable {
    case none, protected, unprotected
}

// MARK: - Advanced field enums

enum BloodColor: String, CaseIterable, Codable, Sendable, SharePermitted {
    case bright, dark, brown
    static var shareability: Shareability { .softenedOptIn }
}

/// Clot size — `large` is the clinically significant ≥2.5 cm threshold that feeds
/// the heavy-bleeding flag (`docs/product/01-data-model.md` rule thresholds).
enum ClotSize: String, CaseIterable, Codable, Sendable, SharePermitted {
    case none, small, large
    static var shareability: Shareability { .softenedOptIn }
}

enum PainLocation: String, CaseIterable, Codable, Sendable, SharePermitted {
    case pelvic, lowBack, legRadiating, oneSided
    static var shareability: Shareability { .softenedOptIn }
}

/// Basal body temperature. Unit-tagged so charts and the symptothermal method
/// never mix scales.
struct BasalBodyTemperature: Equatable, Codable, Sendable, SharePermitted {
    enum Unit: String, CaseIterable, Codable, Sendable { case celsius, fahrenheit }
    let value: Double
    let unit: Unit

    init(_ value: Double, _ unit: Unit) {
        self.value = value
        self.unit = unit
    }

    static var shareability: Shareability { .softenedOptIn }
}

/// Cervical mucus, ordered driest → most fertile (`docs/product/01-data-model.md`).
enum CervicalMucus: String, CaseIterable, Codable, Sendable, Comparable, SharePermitted {
    case dry, sticky, creamy, eggwhite

    static var shareability: Shareability { .softenedOptIn }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}

/// Cervical position, ordered least → most fertile. The fertile end is the SHOW
/// sign — **S**oft, **H**igh, **O**pen, **W**et (`docs/product/01-data-model.md`).
enum CervicalPosition: String, CaseIterable, Codable, Sendable, Comparable, SharePermitted {
    case firmLowClosed, medium, softHighOpen

    static var shareability: Shareability { .softenedOptIn }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}

enum LHTest: String, CaseIterable, Codable, Sendable, SharePermitted {
    case negative, positive
    static var shareability: Shareability { .softenedOptIn }
}

/// A medication entry. **Un-shareable** — a coercion + legal-risk surface with no
/// supportive value to a partner (`docs/research/03` default matrix).
struct Medication: Equatable, Codable, Sendable, NeverShareable {
    enum Kind: String, CaseIterable, Codable, Sendable {
        case painRelief, hormonal, contraceptive, supplement, other
    }
    let name: String
    let type: Kind
    let taken: Bool
    let time: Date?

    init(name: String, type: Kind, taken: Bool, time: Date? = nil) {
        self.name = name
        self.type = type
        self.taken = taken
        self.time = time
    }
}

/// Vaginal discharge, with optional concern flags that can feed a clinical flag.
struct Discharge: Equatable, Codable, Sendable, SharePermitted {
    enum Kind: String, CaseIterable, Codable, Sendable {
        case none, white, yellow, green, grey, watery
    }
    let type: Kind
    let hasOdor: Bool
    let hasItch: Bool

    init(type: Kind, hasOdor: Bool = false, hasItch: Bool = false) {
        self.type = type
        self.hasOdor = hasOdor
        self.hasItch = hasItch
    }

    static var shareability: Shareability { .softenedOptIn }
}

enum Digestion: String, CaseIterable, Codable, Sendable, SharePermitted {
    case normal, bloated, constipated, loose, nauseous
    static var shareability: Shareability { .softenedOptIn }
}

enum HeadacheSeverity: String, CaseIterable, Codable, Sendable, SharePermitted {
    case none, mild, moderate, severe
    static var shareability: Shareability { .softenedOptIn }
}

enum Craving: String, CaseIterable, Codable, Sendable, SharePermitted {
    case none, sweet, salty, carb, savory
    static var shareability: Shareability { .softenedOptIn }
}

enum SkinCondition: String, CaseIterable, Codable, Sendable, SharePermitted {
    case clear, acne, oily, dry, breakout
    static var shareability: Shareability { .softenedOptIn }
}

enum SleepQuality: String, CaseIterable, Codable, Sendable, SharePermitted {
    case poor, fair, good
    static var shareability: Shareability { .softenedOptIn }
}

enum Libido: String, CaseIterable, Codable, Sendable, SharePermitted {
    case low, normal, high
    static var shareability: Shareability { .softenedOptIn }
}

/// A free-text journal note. A note tagged **Private** is un-shareable *and*
/// invisible-that-it-exists (`docs/research/03` §4). Sharing is per-note opt-in,
/// never per-app — so this value type gates sharing on `isPrivate` at the value
/// level rather than the type level.
struct Note: Equatable, Codable, Sendable {
    /// Length cap keeps notes to a fridge-magnet scale, not a diary dump.
    static let maxLength = 2000
    let text: String
    let isPrivate: Bool

    init(text: String, isPrivate: Bool = false) {
        self.text = String(text.prefix(Self.maxLength))
        self.isPrivate = isPrivate
    }

    /// The text that may ever be offered for per-note sharing. A Private note
    /// returns `nil` — it can never be surfaced, promoted, or hinted at.
    var shareableText: String? { isPrivate ? nil : text }
}

// MARK: - DailyLog

/// One log per calendar day; every field optional (`docs/product/01-data-model.md`).
/// The backbone entity — pure value type, chartable, flag-able. No storage/UI here.
struct DailyLog: Equatable, Codable, Sendable, Identifiable {
    let id: UUID
    /// The day this log describes (start-of-day). One `DailyLog` per calendar day.
    let date: Date

    // Core
    var flow: Flow?
    var crampSeverity: CrampSeverity?
    var mood: Set<Mood>
    var energy: Energy?
    var pms: Set<PMSSymptom>
    var sexActivity: SexActivity?

    // Advanced
    var bloodColor: BloodColor?
    var clotSize: ClotSize?
    var painLocation: Set<PainLocation>
    var bbt: BasalBodyTemperature?
    var cervicalMucus: CervicalMucus?
    var cervicalPosition: CervicalPosition?
    var lhTest: LHTest?
    var medications: [Medication]
    var discharge: Discharge?
    var digestion: Digestion?
    var headache: HeadacheSeverity?
    var cravings: Set<Craving>
    var skin: SkinCondition?
    var sleepQuality: SleepQuality?
    var weight: BodyWeight?
    var waterIntake: Int?
    var libido: Libido?
    var note: Note?

    init(
        id: UUID = UUID(),
        date: Date,
        flow: Flow? = nil,
        crampSeverity: CrampSeverity? = nil,
        mood: Set<Mood> = [],
        energy: Energy? = nil,
        pms: Set<PMSSymptom> = [],
        sexActivity: SexActivity? = nil,
        bloodColor: BloodColor? = nil,
        clotSize: ClotSize? = nil,
        painLocation: Set<PainLocation> = [],
        bbt: BasalBodyTemperature? = nil,
        cervicalMucus: CervicalMucus? = nil,
        cervicalPosition: CervicalPosition? = nil,
        lhTest: LHTest? = nil,
        medications: [Medication] = [],
        discharge: Discharge? = nil,
        digestion: Digestion? = nil,
        headache: HeadacheSeverity? = nil,
        cravings: Set<Craving> = [],
        skin: SkinCondition? = nil,
        sleepQuality: SleepQuality? = nil,
        weight: BodyWeight? = nil,
        waterIntake: Int? = nil,
        libido: Libido? = nil,
        note: Note? = nil
    ) {
        self.id = id
        self.date = date
        self.flow = flow
        self.crampSeverity = crampSeverity
        self.mood = mood
        self.energy = energy
        self.pms = pms
        self.sexActivity = sexActivity
        self.bloodColor = bloodColor
        self.clotSize = clotSize
        self.painLocation = painLocation
        self.bbt = bbt
        self.cervicalMucus = cervicalMucus
        self.cervicalPosition = cervicalPosition
        self.lhTest = lhTest
        self.medications = medications
        self.discharge = discharge
        self.digestion = digestion
        self.headache = headache
        self.cravings = cravings
        self.skin = skin
        self.sleepQuality = sleepQuality
        self.weight = weight
        self.waterIntake = waterIntake
        self.libido = libido
        self.note = note
    }
}

/// Body weight. **Un-shareable** — no care value, high shame/control value
/// (`docs/research/03` default matrix).
struct BodyWeight: Equatable, Codable, Sendable, NeverShareable {
    enum Unit: String, CaseIterable, Codable, Sendable { case kilograms, pounds }
    let value: Double
    let unit: Unit

    init(_ value: Double, _ unit: Unit) {
        self.value = value
        self.unit = unit
    }
}
