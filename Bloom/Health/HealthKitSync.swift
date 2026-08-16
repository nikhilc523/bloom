import Foundation
import HealthKit

// MARK: - HealthKit two-way sync (Stage 5)
//
// Writing reproductive-health samples to HealthKit *is* the two-way sync with
// Apple's Cycle Tracking (see `.claude/skills/healthkit-integration/SKILL.md`).
// Bloom mirrors the handful of DailyLog fields that have a true HealthKit home,
// and ingests external samples (Apple Watch, other apps) back into her logs.
//
// Design:
//   • `HealthKitFieldMapping` — PURE, device-free translation DailyLog ⇄ HKSample.
//     Unit-testable on any platform (CI never touches a real Health store).
//   • `HealthKitSync` — @MainActor. Authorization, write-through, and live ingest
//     (observer + background delivery + anchored delta). No-ops when HealthKit is
//     unavailable (Simulator / iPad / denied), exactly like the Stage-4 CloudKit gate.
//   • `HealthKitMirroringLogRepository` — a LogRepository decorator that mirrors
//     writes to HealthKit *after* the SwiftData write succeeds, so call sites are
//     unchanged and a HK failure never fails her save.

// MARK: - Pure field mapping (testable, no device required)

/// Translates between Bloom's `DailyLog` fields and HealthKit samples. Every
/// mapping is intentionally lossy-safe and documented in the skill's mapping table.
/// This type never touches an `HKHealthStore`, so it runs (and is tested) anywhere.
enum HealthKitFieldMapping {

    /// The category/quantity types Bloom writes and reads. Read == write here:
    /// every field we mirror out we also ingest back.
    static var categoryTypes: [HKCategoryType] {
        [
            HKCategoryType(.menstrualFlow),
            HKCategoryType(.cervicalMucusQuality),
            HKCategoryType(.ovulationTestResult),
            HKCategoryType(.sexualActivity),
        ]
    }

    static var quantityTypes: [HKQuantityType] {
        [HKQuantityType(.basalBodyTemperature)]
    }

    static var typesToShare: Set<HKSampleType> {
        Set(categoryTypes as [HKSampleType] + quantityTypes as [HKSampleType])
    }

    static var typesToRead: Set<HKObjectType> {
        Set(categoryTypes as [HKObjectType] + quantityTypes as [HKObjectType])
    }

    // MARK: DailyLog → HKSample (write-through)

    /// The HealthKit samples that represent `log` on its day. `isPeriodStart`
    /// marks the first day of a period so Apple's Cycle Tracking registers a cycle
    /// start (metadata `HKMetadataKeyMenstrualCycleStart`).
    static func samples(for log: DailyLog, isPeriodStart: Bool) -> [HKSample] {
        // One calendar day, point-in-time at local noon to dodge timezone-boundary drift.
        let day = Calendar.current.startOfDay(for: log.date)
        let at = Calendar.current.date(byAdding: .hour, value: 12, to: day) ?? day
        var out: [HKSample] = []

        if let flow = log.flow, let value = menstrualFlowValue(for: flow) {
            var metadata: [String: Any] = [HKMetadataKeyMenstrualCycleStart: isPeriodStart]
            // (empty-flow days still record cycle-start=false, which is correct.)
            out.append(HKCategorySample(
                type: HKCategoryType(.menstrualFlow),
                value: value.rawValue,
                start: at, end: at,
                metadata: metadata
            ))
            metadata.removeAll()
        }

        if let mucus = log.cervicalMucus {
            out.append(HKCategorySample(
                type: HKCategoryType(.cervicalMucusQuality),
                value: cervicalMucusValue(for: mucus).rawValue,
                start: at, end: at
            ))
        }

        if let lh = log.lhTest {
            out.append(HKCategorySample(
                type: HKCategoryType(.ovulationTestResult),
                value: ovulationValue(for: lh).rawValue,
                start: at, end: at
            ))
        }

        if let sex = log.sexActivity, let protectionUsed = protectionUsed(for: sex) {
            out.append(HKCategorySample(
                type: HKCategoryType(.sexualActivity),
                value: HKCategoryValue.notApplicable.rawValue,
                start: at, end: at,
                metadata: [HKMetadataKeySexualActivityProtectionUsed: protectionUsed]
            ))
        }

        if let bbt = log.bbt {
            let quantity = HKQuantity(unit: hkUnit(for: bbt.unit), doubleValue: bbt.value)
            out.append(HKQuantitySample(
                type: HKQuantityType(.basalBodyTemperature),
                quantity: quantity,
                start: at, end: at
            ))
        }

        return out
    }

    // MARK: HKSample → DailyLog field (ingest)

    /// Applies an ingested external sample onto `log`, returning the mutated log
    /// (or `nil` if the sample isn't one we map). Caller upserts the result.
    static func apply(_ sample: HKSample, to log: DailyLog) -> DailyLog? {
        var log = log
        switch sample {
        case let c as HKCategorySample where c.categoryType == HKCategoryType(.menstrualFlow):
            guard let v = HKCategoryValueMenstrualFlow(rawValue: c.value) else { return nil }
            log.flow = flow(for: v)
        case let c as HKCategorySample where c.categoryType == HKCategoryType(.cervicalMucusQuality):
            guard let v = HKCategoryValueCervicalMucusQuality(rawValue: c.value) else { return nil }
            log.cervicalMucus = cervicalMucus(for: v)
        case let c as HKCategorySample where c.categoryType == HKCategoryType(.ovulationTestResult):
            guard let v = HKCategoryValueOvulationTestResult(rawValue: c.value) else { return nil }
            log.lhTest = lhTest(for: v)
        case let c as HKCategorySample where c.categoryType == HKCategoryType(.sexualActivity):
            let protectionUsed = c.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool
            log.sexActivity = sexActivity(protectionUsed: protectionUsed)
        case let q as HKQuantitySample where q.quantityType == HKQuantityType(.basalBodyTemperature):
            // Read back in Celsius; unit tag is normalized on ingest.
            let celsius = q.quantity.doubleValue(for: .degreeCelsius())
            log.bbt = BasalBodyTemperature(celsius, .celsius)
        default:
            return nil
        }
        return log
    }

    // MARK: value maps (kept in lockstep with the skill's table)

    static func menstrualFlowValue(for flow: Flow) -> HKCategoryValueMenstrualFlow? {
        switch flow {
        case .none: HKCategoryValueMenstrualFlow.none
        case .spotting: .light   // no HK "spotting" peer → light (documented loss)
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        }
    }

    static func flow(for value: HKCategoryValueMenstrualFlow) -> Flow {
        switch value {
        case .none: Flow.none
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .unspecified: .light   // unknown intensity → light
        @unknown default: .light
        }
    }

    static func cervicalMucusValue(for mucus: CervicalMucus) -> HKCategoryValueCervicalMucusQuality {
        switch mucus {
        case .dry: .dry
        case .sticky: .sticky
        case .creamy: .creamy
        case .eggwhite: .eggWhite
        }
    }

    static func cervicalMucus(for value: HKCategoryValueCervicalMucusQuality) -> CervicalMucus {
        switch value {
        case .dry: .dry
        case .sticky: .sticky
        case .creamy: .creamy
        case .watery: .creamy     // no Bloom "watery" → nearest (creamy)
        case .eggWhite: .eggwhite
        @unknown default: .creamy
        }
    }

    static func ovulationValue(for lh: LHTest) -> HKCategoryValueOvulationTestResult {
        switch lh {
        case .negative: .negative
        case .positive: .luteinizingHormoneSurge
        }
    }

    static func lhTest(for value: HKCategoryValueOvulationTestResult) -> LHTest {
        switch value {
        case .negative: .negative
        case .luteinizingHormoneSurge, .estrogenSurge, .positive: .positive
        case .indeterminate: .negative
        @unknown default: .negative
        }
    }

    /// `none` → no sample (nil); protected → true, unprotected → false.
    static func protectionUsed(for sex: SexActivity) -> Bool? {
        switch sex {
        case .none: nil
        case .protected: true
        case .unprotected: false
        }
    }

    static func sexActivity(protectionUsed: Bool?) -> SexActivity {
        switch protectionUsed {
        case .some(true): .protected
        case .some(false): .unprotected
        case .none: .none
        }
    }

    static func hkUnit(for unit: BasalBodyTemperature.Unit) -> HKUnit {
        switch unit {
        case .celsius: .degreeCelsius()
        case .fahrenheit: .degreeFahrenheit()
        }
    }
}

// MARK: - Anchor persistence (delta ingest state)

/// Persists one `HKQueryAnchor` per observed type so each ingest only pulls what
/// changed. Archive round-trip is pure/testable; storage is `UserDefaults`.
struct HealthKitAnchorStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(for identifier: String) -> String { "hk.anchor.\(identifier)" }

    func anchor(for identifier: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: key(for: identifier)) else { return nil }
        return Self.decode(data)
    }

    func setAnchor(_ anchor: HKQueryAnchor, for identifier: String) {
        guard let data = Self.encode(anchor) else { return }
        defaults.set(data, forKey: key(for: identifier))
    }

    /// Archive/unarchive helpers — pure, so a unit test can prove the round-trip.
    static func encode(_ anchor: HKQueryAnchor) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    static func decode(_ data: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}

// MARK: - HealthKitSync (device-only I/O)

/// Owns the live HealthKit connection: authorization, write-through, and ingest.
/// `@MainActor` because ingest merges touch the (main-actor) `ModelContext` via the
/// repository. Every entry point no-ops when HealthKit is unavailable.
@MainActor
final class HealthKitSync {
    private let healthStore = HKHealthStore()
    private let anchors: HealthKitAnchorStore
    /// Where ingested external samples are merged. Injected so ingest can upsert.
    private let logRepository: any LogRepository
    private var observers: [HKObserverQuery] = []

    init(logRepository: any LogRepository, anchors: HealthKitAnchorStore = HealthKitAnchorStore()) {
        self.logRepository = logRepository
        self.anchors = anchors
    }

    /// Guards every path. **False on the Simulator by design** — like the Stage-4
    /// CloudKit gate, this is mandatory, not defensive: modern simulators report
    /// `isHealthDataAvailable() == true`, but they carry no HealthKit entitlement,
    /// so `requestAuthorization` throws "Missing entitlement." Every simulator path
    /// here is unsigned (CI with `CODE_SIGNING_ALLOWED=NO`, local QA), so HK must
    /// stay off there and validation happens on a signed device build.
    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return HKHealthStore.isHealthDataAvailable()
        #endif
    }

    // MARK: Authorization

    /// Request read+write once. Never inspect read status afterwards (unknowable
    /// by design); if reads come back empty, treat as "no data," not "denied."
    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await healthStore.requestAuthorization(
                toShare: HealthKitFieldMapping.typesToShare,
                read: HealthKitFieldMapping.typesToRead
            )
        } catch {
            // Auth failures are non-fatal and must NEVER trap: the app works fully
            // without HealthKit. (A missing-entitlement error here would otherwise
            // crash an unsigned build — see the simulator gate above.)
            #if DEBUG
            print("HealthKit authorization failed: \(error)")
            #endif
        }
    }

    // MARK: Write-through (hers → Health)

    /// Mirror one day's log to HealthKit. Idempotent: deletes Bloom-authored
    /// samples of each mapped type on that day, then inserts the current values.
    func mirror(_ log: DailyLog, isPeriodStart: Bool) async {
        guard isAvailable else { return }
        let day = Calendar.current.startOfDay(for: log.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let dayPredicate = HKQuery.predicateForSamples(withStart: day, end: end, options: [.strictStartDate])
        let newSamples = HealthKitFieldMapping.samples(for: log, isPeriodStart: isPeriodStart)

        do {
            // Remove our own prior samples for the mapped types on this day so a
            // re-log doesn't pile up duplicates (HealthKit has no upsert).
            for type in HealthKitFieldMapping.typesToShare {
                try await deleteBloomAuthored(of: type, matching: dayPredicate)
            }
            if !newSamples.isEmpty {
                try await healthStore.save(newSamples)
            }
        } catch {
            // The SwiftData write already succeeded and is authoritative; a HK
            // failure is logged, never surfaced as a save failure.
            #if DEBUG
            print("HealthKit mirror failed for \(day): \(error)")
            #endif
        }
    }

    /// Delete only samples Bloom itself wrote (source == default source) for a
    /// type on a day — never touch samples other apps/devices contributed.
    private func deleteBloomAuthored(of type: HKSampleType, matching dayPredicate: NSPredicate) async throws {
        let mine = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dayPredicate, mine])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.deleteObjects(of: type, predicate: predicate) { _, _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    // MARK: Live ingest (Health → hers)

    /// Start observing every mapped type and enable background delivery so
    /// external changes wake the app. Call once, after authorization.
    func startObserving() async {
        guard isAvailable else { return }
        for type in HealthKitFieldMapping.typesToShare {
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                if error == nil, let self {
                    // Ingest the delta on the main actor (ModelContext is main-bound).
                    Task { @MainActor in await self.ingestChanges(for: type) }
                }
                // Signal HealthKit the notification is handled. `completion` is not
                // Sendable, so it stays out of the actor hop (Swift 6 data-race rule);
                // for daily-frequency reproductive types this ordering is fine.
                completion()
            }
            healthStore.execute(observer)
            observers.append(observer)
            do {
                // Reproductive category types are capped at daily frequency by HK.
                try await healthStore.enableBackgroundDelivery(for: type, frequency: .daily)
            } catch {
                #if DEBUG
                print("HealthKit background delivery failed for \(type): \(error)")
                #endif
            }
        }
    }

    /// Fetch the delta for a type since the persisted anchor and merge external
    /// samples into her logs. Bloom-authored samples are skipped (no feedback loop).
    func ingestChanges(for type: HKSampleType) async {
        guard isAvailable else { return }
        let identifier = type.identifier
        let previous = anchors.anchor(for: identifier)
        let predicate = samplePredicate(for: type)
        do {
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [predicate], anchor: previous)
            let result = try await descriptor.result(for: healthStore)
            for sample in result.addedSamples where !isBloomAuthored(sample) {
                await merge(sample)
            }
            anchors.setAnchor(result.newAnchor, for: identifier)
        } catch {
            #if DEBUG
            print("HealthKit ingest failed for \(identifier): \(error)")
            #endif
        }
    }

    private func samplePredicate(for type: HKSampleType) -> HKSamplePredicate<HKSample> {
        .sample(type: type)
    }

    private func isBloomAuthored(_ sample: HKSample) -> Bool {
        sample.sourceRevision.source == HKSource.default()
    }

    /// Merge one external sample into its day's log via the repository upsert.
    private func merge(_ sample: HKSample) async {
        let day = Calendar.current.startOfDay(for: sample.startDate)
        do {
            let existing = try logRepository.log(on: day) ?? DailyLog(date: day)
            guard let updated = HealthKitFieldMapping.apply(sample, to: existing) else { return }
            try logRepository.upsert(updated)
        } catch {
            #if DEBUG
            print("HealthKit merge failed for \(day): \(error)")
            #endif
        }
    }
}

// MARK: - Write-through decorator

/// A `LogRepository` that mirrors writes to HealthKit after the wrapped store
/// commits them. Call sites (`ContentView`, future log UI) use this exactly like
/// the plain repository — HealthKit stays invisible to them.
@MainActor
final class HealthKitMirroringLogRepository: LogRepository {
    private let base: any LogRepository
    private let sync: HealthKitSync

    init(base: any LogRepository, sync: HealthKitSync) {
        self.base = base
        self.sync = sync
    }

    func upsert(_ log: DailyLog) throws {
        try base.upsert(log)   // authoritative write first
        let periodStart = isPeriodStart(for: log)
        // Mirror off the critical path; a HK failure never fails her save.
        Task { await sync.mirror(log, isPeriodStart: periodStart) }
    }

    func log(on date: Date) throws -> DailyLog? { try base.log(on: date) }
    func logs(in range: ClosedRange<Date>) throws -> [DailyLog] { try base.logs(in: range) }
    func allLogs() throws -> [DailyLog] { try base.allLogs() }

    func deleteLog(on date: Date) throws {
        try base.deleteLog(on: date)
        let empty = DailyLog(date: Calendar.current.startOfDay(for: date))
        Task { await sync.mirror(empty, isPeriodStart: false) }   // clears mirrored samples
    }

    /// A period's first day = flow present today, and no flow the day before.
    /// Cycle Tracking needs this to register the period start.
    private func isPeriodStart(for log: DailyLog) -> Bool {
        guard let flow = log.flow, flow != .none else { return false }
        let day = Calendar.current.startOfDay(for: log.date)
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: day) else { return true }
        let priorFlow = (try? base.log(on: yesterday))?.flow
        return priorFlow == nil || priorFlow == Flow.none
    }
}
