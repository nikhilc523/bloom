import Foundation
import SwiftData

// MARK: - Storage architecture (docs/product/01-data-model.md §Storage split)
//
// These `@Model` entities persist ONLY her private cycle data. The partner shared
// layer (SharedState, PinnedNote) lives in a CloudKit custom zone + CKShare and is
// NEVER stored here (SwiftData can't use the shared DB) — keep the stores separate.
//
// Every entity is CloudKit-private-DB-READY (see `swiftdata-cloudkit-setup` skill):
//   • every stored property is optional or defaulted,
//   • no `@Attribute(.unique)` (identity is enforced in the repository),
//   • no cross-entity relationships.
// Each entity stores its Stage-1 pure value type as an authoritative Codable
// `payload` (Data), plus a few optional/defaulted scalar columns used ONLY for
// `#Predicate` filtering and sorting. The payload is the single source of truth;
// scalar columns are derived on write. `toDomain()` reads only the payload.

// MARK: - Coder + errors

/// Deterministic Codable bridge shared by every entity. Dates encode as their
/// numeric time-interval (stable across launches), so round-trips are exact.
enum BloomStoreCoder {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

/// Failure modes when bridging an entity to/from its domain value type.
enum StoreError: Error, Equatable {
    /// The entity row exists but its Codable payload is missing (never written,
    /// or a schema/data-corruption issue). The domain object cannot be rebuilt.
    case missingPayload
}

// MARK: - UserEntity  (domain: `User`)

@Model
final class UserEntity {
    /// Queryable identity (also the domain `User.id`). Not `.unique` — CloudKit
    /// forbids unique constraints; single-user invariant is enforced by the repo.
    var id: UUID?
    /// Authoritative Codable `User`.
    var payload: Data?

    init() {}

    static func make(_ user: User) throws -> UserEntity {
        let entity = UserEntity()
        try entity.apply(user)
        return entity
    }

    func apply(_ user: User) throws {
        id = user.id
        payload = try BloomStoreCoder.encode(user)
    }

    func toDomain() throws -> User {
        guard let payload else { throw StoreError.missingPayload }
        return try BloomStoreCoder.decode(User.self, from: payload)
    }
}

// MARK: - CycleEntity  (domain: `CycleRecord`)

@Model
final class CycleEntity {
    var id: UUID?
    /// Sort key for building history windows.
    var startDate: Date?
    /// Predicted cycles render ghost/dashed and are excluded from every rule —
    /// a column so the repo can filter `!isPredicted` without decoding payloads.
    var isPredicted: Bool = false
    /// Authoritative Codable `CycleRecord`.
    var payload: Data?

    init() {}

    static func make(_ record: CycleRecord) throws -> CycleEntity {
        let entity = CycleEntity()
        try entity.apply(record)
        return entity
    }

    func apply(_ record: CycleRecord) throws {
        id = record.id
        startDate = record.startDate
        isPredicted = record.isPredicted
        payload = try BloomStoreCoder.encode(record)
    }

    func toDomain() throws -> CycleRecord {
        guard let payload else { throw StoreError.missingPayload }
        return try BloomStoreCoder.decode(CycleRecord.self, from: payload)
    }
}

// MARK: - DailyLogEntity  (domain: `DailyLog`)

@Model
final class DailyLogEntity {
    var id: UUID?
    /// The calendar day this log describes (start-of-day). One log per day is a
    /// repository invariant (fetch-then-upsert), not a schema unique constraint.
    var date: Date?
    /// Authoritative Codable `DailyLog` — all ~24 optional fields, incl. the
    /// un-shareable ones (sex, weight, meds, Private note) which live ONLY here.
    var payload: Data?

    init() {}

    static func make(_ log: DailyLog) throws -> DailyLogEntity {
        let entity = DailyLogEntity()
        try entity.apply(log)
        return entity
    }

    func apply(_ log: DailyLog) throws {
        id = log.id
        date = log.date
        payload = try BloomStoreCoder.encode(log)
    }

    func toDomain() throws -> DailyLog {
        guard let payload else { throw StoreError.missingPayload }
        return try BloomStoreCoder.decode(DailyLog.self, from: payload)
    }
}

// MARK: - PredictionEntity  (domain: `Prediction`)

@Model
final class PredictionEntity {
    /// `Prediction` has no domain id; this is the row identity for replace/update.
    var id: UUID?
    /// Sort key — the latest prediction wins.
    var generatedAt: Date?
    /// Authoritative Codable `Prediction`.
    var payload: Data?

    init() {}

    static func make(_ prediction: Prediction, id: UUID = UUID()) throws -> PredictionEntity {
        let entity = PredictionEntity()
        entity.id = id
        try entity.apply(prediction)
        return entity
    }

    func apply(_ prediction: Prediction) throws {
        generatedAt = prediction.generatedAt
        payload = try BloomStoreCoder.encode(prediction)
    }

    func toDomain() throws -> Prediction {
        guard let payload else { throw StoreError.missingPayload }
        return try BloomStoreCoder.decode(Prediction.self, from: payload)
    }
}

// MARK: - ClinicalFlagEntity  (domain: `ClinicalFlag`)

@Model
final class ClinicalFlagEntity {
    var id: UUID?
    /// Raw `FlagType` for filtering by category without decoding.
    var typeRaw: String?
    /// Sort key (most recent first).
    var createdAt: Date?
    /// Column so the repo can fetch only active (non-dismissed) flags.
    var dismissed: Bool = false
    /// Authoritative Codable `ClinicalFlag` (message already carries the
    /// clinician suffix — never a diagnosis).
    var payload: Data?

    init() {}

    static func make(_ flag: ClinicalFlag) throws -> ClinicalFlagEntity {
        let entity = ClinicalFlagEntity()
        try entity.apply(flag)
        return entity
    }

    func apply(_ flag: ClinicalFlag) throws {
        id = flag.id
        typeRaw = flag.type.rawValue
        createdAt = flag.createdAt
        dismissed = flag.dismissed
        payload = try BloomStoreCoder.encode(flag)
    }

    func toDomain() throws -> ClinicalFlag {
        guard let payload else { throw StoreError.missingPayload }
        return try BloomStoreCoder.decode(ClinicalFlag.self, from: payload)
    }
}
