import Foundation
import SwiftData

// MARK: - Repository protocols
//
// The UI and engines talk to these protocols, never to SwiftData directly, so
// storage stays swappable and the domain surface is pure value types in/out.
// Everything is `@MainActor`: `ModelContext` is NOT `Sendable`, so the context
// is never crossed to another actor (see `swift-bug-finder` / Swift 6 rules).
//
// Data volume is one owner's cycle history (hundreds of rows at most), so reads
// fetch + filter/sort in Swift rather than lean on optional-column `#Predicate`s —
// simpler and less error-prone. Revisit if a dataset ever grows large.

/// Persistence for her daily logs. One `DailyLog` per calendar day (upsert by day).
@MainActor
protocol LogRepository {
    func upsert(_ log: DailyLog) throws
    func log(on date: Date) throws -> DailyLog?
    func logs(in range: ClosedRange<Date>) throws -> [DailyLog]
    func allLogs() throws -> [DailyLog]
    func deleteLog(on date: Date) throws
}

/// Persistence for cycles, the user record, predictions, and clinical flags —
/// the "private cycle" domain root.
@MainActor
protocol CycleRepository {
    // Cycles
    func addOrUpdate(_ record: CycleRecord) throws
    func allCycles() throws -> [CycleRecord]
    func completedCycles() throws -> [CycleRecord]
    func deleteCycle(id: UUID) throws

    // User (single owner — "she is the data controller")
    func currentUser() throws -> User?
    func save(_ user: User) throws

    // Prediction (only the latest snapshot is kept)
    func saveLatestPrediction(_ prediction: Prediction) throws
    func latestPrediction() throws -> Prediction?

    // Clinical flags
    func raise(_ flags: [ClinicalFlag]) throws
    func activeFlags() throws -> [ClinicalFlag]
    func dismissFlag(id: UUID) throws
}

// MARK: - SwiftData-backed implementation

/// The concrete repository. Build one per context; the app uses the container's
/// `mainContext`, tests use an in-memory container's context.
@MainActor
final class SwiftDataRepository: LogRepository, CycleRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Convenience: repository over a container's main context.
    convenience init(container: ModelContainer, calendar: Calendar = .current) {
        self.init(context: container.mainContext, calendar: calendar)
    }

    // MARK: LogRepository

    func upsert(_ log: DailyLog) throws {
        let day = calendar.startOfDay(for: log.date)
        if let existing = try logEntity(onDay: day) {
            try existing.apply(log)
        } else {
            context.insert(try DailyLogEntity.make(log))
        }
        try context.save()
    }

    func log(on date: Date) throws -> DailyLog? {
        let day = calendar.startOfDay(for: date)
        return try logEntity(onDay: day)?.toDomain()
    }

    func logs(in range: ClosedRange<Date>) throws -> [DailyLog] {
        try allLogs().filter { range.contains($0.date) }
    }

    func allLogs() throws -> [DailyLog] {
        try context.fetch(FetchDescriptor<DailyLogEntity>())
            .map { try $0.toDomain() }
            .sorted { $0.date < $1.date }
    }

    func deleteLog(on date: Date) throws {
        let day = calendar.startOfDay(for: date)
        if let existing = try logEntity(onDay: day) {
            context.delete(existing)
            try context.save()
        }
    }

    /// The single log entity whose stored day matches `day` (already start-of-day).
    private func logEntity(onDay day: Date) throws -> DailyLogEntity? {
        try context.fetch(FetchDescriptor<DailyLogEntity>()).first {
            guard let stored = $0.date else { return false }
            return calendar.startOfDay(for: stored) == day
        }
    }

    // MARK: CycleRepository — cycles

    func addOrUpdate(_ record: CycleRecord) throws {
        if let existing = try cycleEntity(id: record.id) {
            try existing.apply(record)
        } else {
            context.insert(try CycleEntity.make(record))
        }
        try context.save()
    }

    func allCycles() throws -> [CycleRecord] {
        try context.fetch(FetchDescriptor<CycleEntity>())
            .map { try $0.toDomain() }
            .sorted { $0.startDate < $1.startDate }
    }

    func completedCycles() throws -> [CycleRecord] {
        try allCycles().filter { !$0.isPredicted }
    }

    func deleteCycle(id: UUID) throws {
        if let existing = try cycleEntity(id: id) {
            context.delete(existing)
            try context.save()
        }
    }

    private func cycleEntity(id: UUID) throws -> CycleEntity? {
        try context.fetch(FetchDescriptor<CycleEntity>()).first { $0.id == id }
    }

    // MARK: CycleRepository — user

    func currentUser() throws -> User? {
        try context.fetch(FetchDescriptor<UserEntity>())
            .compactMap { try? $0.toDomain() }
            .min { $0.onboardedAt < $1.onboardedAt }
    }

    func save(_ user: User) throws {
        let existing = try context.fetch(FetchDescriptor<UserEntity>())
        if let match = existing.first(where: { $0.id == user.id }) {
            try match.apply(user)
        } else {
            context.insert(try UserEntity.make(user))
        }
        try context.save()
    }

    // MARK: CycleRepository — prediction

    func saveLatestPrediction(_ prediction: Prediction) throws {
        // Only the latest snapshot is kept — clear any prior rows first.
        for stale in try context.fetch(FetchDescriptor<PredictionEntity>()) {
            context.delete(stale)
        }
        context.insert(try PredictionEntity.make(prediction))
        try context.save()
    }

    func latestPrediction() throws -> Prediction? {
        try context.fetch(FetchDescriptor<PredictionEntity>())
            .compactMap { entity -> (Date, Prediction)? in
                guard let domain = try? entity.toDomain() else { return nil }
                return (domain.generatedAt, domain)
            }
            .max { $0.0 < $1.0 }?
            .1
    }

    // MARK: CycleRepository — clinical flags

    func raise(_ flags: [ClinicalFlag]) throws {
        for flag in flags {
            if let existing = try flagEntity(id: flag.id) {
                try existing.apply(flag)
            } else {
                context.insert(try ClinicalFlagEntity.make(flag))
            }
        }
        try context.save()
    }

    func activeFlags() throws -> [ClinicalFlag] {
        try context.fetch(FetchDescriptor<ClinicalFlagEntity>())
            .compactMap { try? $0.toDomain() }
            .filter { !$0.dismissed }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func dismissFlag(id: UUID) throws {
        guard let entity = try flagEntity(id: id) else { return }
        var flag = try entity.toDomain()
        flag.dismissed = true
        try entity.apply(flag)
        try context.save()
    }

    private func flagEntity(id: UUID) throws -> ClinicalFlagEntity? {
        try context.fetch(FetchDescriptor<ClinicalFlagEntity>()).first { $0.id == id }
    }
}
