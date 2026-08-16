import Foundation
import SwiftData
import Testing
@testable import Bloom

/// Persistence round-trips and repository behaviour. Every test runs against an
/// isolated **in-memory** container (deterministic, no disk/iCloud), except the
/// relaunch-survival test which deliberately uses a temp on-disk store.
///
/// `@MainActor` because `SwiftDataRepository` (and `ModelContext`) are main-actor
/// isolated — Swift 6 will not let a context cross actors.
@MainActor
@Suite("SwiftData store + repository", .serialized)
struct StoreTests {

    // Fixed UTC calendar + reference dates so day-bucketing never flakes on DST.
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        Self.utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// ONE in-memory container for the whole suite. SwiftData traps on fetch when
    /// many in-memory containers coexist in a single process, so we share a single
    /// container (the app does the same — one container per launch) and wipe it
    /// between tests for isolation. The suite is `.serialized`, so no overlap.
    private static let container: ModelContainer = {
        do { return try BloomStore.inMemoryContainer() }
        catch { fatalError("Failed to create in-memory test container: \(error)") }
    }()

    private func makeRepo() throws -> SwiftDataRepository {
        let context = Self.container.mainContext
        // Reset to a clean slate so each test starts empty.
        try context.delete(model: DailyLogEntity.self)
        try context.delete(model: CycleEntity.self)
        try context.delete(model: UserEntity.self)
        try context.delete(model: PredictionEntity.self)
        try context.delete(model: ClinicalFlagEntity.self)
        try context.save()
        return SwiftDataRepository(context: context, calendar: Self.utc)
    }

    // MARK: - Round-trips (encode → store → fetch → decode → equal)

    @Test func dailyLogRoundTripsEveryField() throws {
        let repo = try makeRepo()
        // Include un-shareable fields (sex, weight, Private note) — they must persist
        // in her PRIVATE store faithfully; they simply never reach a partner zone.
        let log = DailyLog(
            date: date(2026, 3, 10),
            flow: .heavy,
            crampSeverity: CrampSeverity(7),
            mood: [.anxious, .low],
            sexActivity: .unprotected,
            clotSize: .large,
            medications: [Medication(name: "Ibuprofen", type: .painRelief, taken: true)],
            weight: BodyWeight(61.2, .kilograms),
            note: Note(text: "rough day", isPrivate: true)
        )
        try repo.upsert(log)

        let fetched = try repo.log(on: date(2026, 3, 10))
        #expect(fetched == log)
        #expect(fetched?.note?.isPrivate == true)
        #expect(fetched?.sexActivity == .unprotected)
    }

    @Test func cycleRecordRoundTrips() throws {
        let repo = try makeRepo()
        let record = CycleRecord(
            startDate: date(2026, 1, 1),
            endDate: date(2026, 1, 6),
            lengthDays: 29,
            periodLengthDays: 5,
            ovulationEstimate: OvulationEstimate(date: date(2026, 1, 15), confidence: 0.6),
            isPredicted: false
        )
        try repo.addOrUpdate(record)
        #expect(try repo.allCycles() == [record])
    }

    @Test func userRoundTrips() throws {
        let repo = try makeRepo()
        let user = User(displayName: "Her", lifeStageMode: .teen,
                        onboardedAt: date(2025, 12, 1), sharingPreset: .minimal)
        try repo.save(user)
        #expect(try repo.currentUser() == user)
    }

    @Test func predictionRoundTrips() throws {
        let repo = try makeRepo()
        let prediction = Prediction(
            nextPeriod: PredictionWindow(windowStart: date(2026, 2, 1),
                                         windowEnd: date(2026, 2, 4), confidence: 0.7),
            generatedAt: date(2026, 1, 20)
        )
        try repo.saveLatestPrediction(prediction)
        #expect(try repo.latestPrediction() == prediction)
    }

    @Test func clinicalFlagRoundTrips() throws {
        let repo = try makeRepo()
        let flag = ClinicalFlag(type: .heavyBleeding, triggeredByRule: "heavy:clot>=2.5cm",
                                severity: .attention, message: "Heavy bleeding noted",
                                createdAt: date(2026, 3, 1))
        try repo.raise([flag])
        #expect(try repo.activeFlags() == [flag])
        // The clinician suffix survives the round-trip (never a diagnosis).
        #expect(try repo.activeFlags().first?.message.hasSuffix(ClinicalFlag.clinicianSuffix) == true)
    }

    // MARK: - Repository behaviour

    @Test func upsertKeepsOnePerDayLatestWins() throws {
        let repo = try makeRepo()
        // Same calendar day, different times → still one row, second value wins.
        try repo.upsert(DailyLog(date: date(2026, 3, 10, 2), flow: .light))
        try repo.upsert(DailyLog(date: date(2026, 3, 10, 20), flow: .heavy))

        #expect(try repo.allLogs().count == 1)
        #expect(try repo.log(on: date(2026, 3, 10))?.flow == .heavy)
    }

    @Test func completedCyclesExcludePredicted() throws {
        let repo = try makeRepo()
        let real = CycleRecord(startDate: date(2026, 1, 1), isPredicted: false)
        let ghost = CycleRecord(startDate: date(2026, 2, 1), isPredicted: true)
        try repo.addOrUpdate(real)
        try repo.addOrUpdate(ghost)

        #expect(try repo.allCycles().count == 2)
        #expect(try repo.completedCycles() == [real])
    }

    @Test func logsInRangeFiltersAndSorts() throws {
        let repo = try makeRepo()
        try repo.upsert(DailyLog(date: date(2026, 3, 1), flow: .light))
        try repo.upsert(DailyLog(date: date(2026, 3, 5), flow: .medium))
        try repo.upsert(DailyLog(date: date(2026, 3, 20), flow: .heavy))

        let inRange = try repo.logs(in: date(2026, 3, 1)...date(2026, 3, 10))
        #expect(inRange.map(\.flow) == [.light, .medium])
    }

    @Test func saveLatestPredictionReplacesPrevious() throws {
        let repo = try makeRepo()
        try repo.saveLatestPrediction(Prediction(
            nextPeriod: PredictionWindow(windowStart: date(2026, 2, 1),
                                         windowEnd: date(2026, 2, 3), confidence: 0.5),
            generatedAt: date(2026, 1, 10)))
        let newer = Prediction(
            nextPeriod: PredictionWindow(windowStart: date(2026, 3, 1),
                                         windowEnd: date(2026, 3, 3), confidence: 0.8),
            generatedAt: date(2026, 2, 10))
        try repo.saveLatestPrediction(newer)

        #expect(try repo.latestPrediction() == newer)
    }

    @Test func dismissFlagRemovesItFromActive() throws {
        let repo = try makeRepo()
        let flag = ClinicalFlag(type: .missedPeriod, triggeredByRule: "missed:>=90d",
                                severity: .attention, message: "No period logged in a while",
                                createdAt: date(2026, 3, 1))
        try repo.raise([flag])
        try repo.dismissFlag(id: flag.id)
        #expect(try repo.activeFlags().isEmpty)
    }

    @Test func deleteLogRemovesIt() throws {
        let repo = try makeRepo()
        try repo.upsert(DailyLog(date: date(2026, 3, 10), flow: .medium))
        try repo.deleteLog(on: date(2026, 3, 10))
        #expect(try repo.allLogs().isEmpty)
    }

    // MARK: - Missing-payload guard

    @Test func toDomainThrowsWhenPayloadMissing() throws {
        let entity = DailyLogEntity() // no payload written
        #expect(throws: StoreError.missingPayload) { try entity.toDomain() }
    }

    // MARK: - Relaunch survival (real on-disk store, not in-memory)

    @Test func logSurvivesContainerRelaunch() throws {
        // Unique temp store URL simulates the app's on-disk store across launches.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bloom-relaunch-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let config = ModelConfiguration(schema: BloomStore.schema, url: url, cloudKitDatabase: .none)
        let log = DailyLog(date: date(2026, 4, 2), flow: .medium, crampSeverity: CrampSeverity(4))

        // Launch #1 — write and persist.
        do {
            let container = try ModelContainer(for: BloomStore.schema, configurations: config)
            let repo = SwiftDataRepository(container: container, calendar: Self.utc)
            try repo.upsert(log)
        }

        // Launch #2 — fresh container over the SAME file. Data must still be there.
        let container = try ModelContainer(for: BloomStore.schema, configurations: config)
        let repo = SwiftDataRepository(container: container, calendar: Self.utc)
        #expect(try repo.log(on: date(2026, 4, 2)) == log)
    }
}
