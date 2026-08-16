import Foundation
import HealthKit
import Testing
@testable import Bloom

// Pure mapping + anchor tests. These need no device or authorization — HKSamples
// can be constructed and inspected on any platform — so they run in CI. The live
// read/write/observe I/O is device-only and verified by hand (see the skill).

@Suite("HealthKit field mapping")
struct HealthKitFieldMappingTests {

    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    // MARK: menstrual flow

    @Test("flow maps to HK value and back", arguments: [
        (Flow.none, HKCategoryValueMenstrualFlow.none),
        (.light, .light),
        (.medium, .medium),
        (.heavy, .heavy),
    ])
    func flowRoundTrip(_ pair: (Flow, HKCategoryValueMenstrualFlow)) {
        #expect(HealthKitFieldMapping.menstrualFlowValue(for: pair.0) == pair.1)
        #expect(HealthKitFieldMapping.flow(for: pair.1) == pair.0)
    }

    @Test("spotting has no HK peer and is recorded as light (documented loss)")
    func spottingIsLossy() {
        #expect(HealthKitFieldMapping.menstrualFlowValue(for: .spotting) == .light)
    }

    @Test("unspecified HK flow ingests as light")
    func unspecifiedIngestsAsLight() {
        #expect(HealthKitFieldMapping.flow(for: .unspecified) == .light)
    }

    // MARK: period-start metadata (Cycle Tracking needs it)

    @Test("first-day flow carries the cycle-start metadata flag")
    func periodStartMetadata() throws {
        let log = DailyLog(date: day, flow: .heavy)
        let samples = HealthKitFieldMapping.samples(for: log, isPeriodStart: true)
        let flowSample = try #require(samples.compactMap { $0 as? HKCategorySample }
            .first { $0.categoryType == HKCategoryType(.menstrualFlow) })
        #expect(flowSample.value == HKCategoryValueMenstrualFlow.heavy.rawValue)
        #expect(flowSample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool == true)
    }

    @Test("a non-first flow day marks cycle-start false")
    func nonFirstDayMetadata() throws {
        let log = DailyLog(date: day, flow: .medium)
        let samples = HealthKitFieldMapping.samples(for: log, isPeriodStart: false)
        let flowSample = try #require(samples.first as? HKCategorySample)
        #expect(flowSample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool == false)
    }

    // MARK: other category types

    @Test("cervical mucus round-trips; watery ingests as creamy")
    func cervicalMucus() {
        #expect(HealthKitFieldMapping.cervicalMucusValue(for: .eggwhite) == .eggWhite)
        #expect(HealthKitFieldMapping.cervicalMucus(for: .eggWhite) == .eggwhite)
        #expect(HealthKitFieldMapping.cervicalMucus(for: .watery) == .creamy)
    }

    @Test("positive LH maps to the LH surge value")
    func ovulation() {
        #expect(HealthKitFieldMapping.ovulationValue(for: .positive) == .luteinizingHormoneSurge)
        #expect(HealthKitFieldMapping.lhTest(for: .luteinizingHormoneSurge) == .positive)
        #expect(HealthKitFieldMapping.lhTest(for: .negative) == .negative)
    }

    @Test("sex activity maps via the protection-used flag; none writes nothing")
    func sexActivity() {
        #expect(HealthKitFieldMapping.protectionUsed(for: .protected) == true)
        #expect(HealthKitFieldMapping.protectionUsed(for: .unprotected) == false)
        #expect(HealthKitFieldMapping.protectionUsed(for: .none) == nil)
        #expect(HealthKitFieldMapping.sexActivity(protectionUsed: true) == .protected)
        #expect(HealthKitFieldMapping.sexActivity(protectionUsed: nil) == .none)
    }

    // MARK: BBT (the one quantity type)

    @Test("BBT writes a Celsius quantity sample and ingests back")
    func bbtRoundTrip() throws {
        let log = DailyLog(date: day, bbt: BasalBodyTemperature(36.7, .celsius))
        let samples = HealthKitFieldMapping.samples(for: log, isPeriodStart: false)
        let bbt = try #require(samples.compactMap { $0 as? HKQuantitySample }
            .first { $0.quantityType == HKQuantityType(.basalBodyTemperature) })
        #expect(abs(bbt.quantity.doubleValue(for: .degreeCelsius()) - 36.7) < 0.001)

        // Ingest it back onto an empty log.
        let updated = try #require(HealthKitFieldMapping.apply(bbt, to: DailyLog(date: day)))
        #expect(updated.bbt?.unit == .celsius)
        #expect(abs((updated.bbt?.value ?? 0) - 36.7) < 0.001)
    }

    // MARK: samples(for:) coverage

    @Test("only mapped fields produce samples; unmapped ones are ignored")
    func onlyMappedFields() {
        // weight/mood/note have no HealthKit home — they must not produce samples.
        let log = DailyLog(
            date: day,
            flow: .medium,
            mood: [.happy],
            bbt: BasalBodyTemperature(36.5, .celsius),
            weight: BodyWeight(60, .kilograms),
            note: Note(text: "private")
        )
        let samples = HealthKitFieldMapping.samples(for: log, isPeriodStart: false)
        #expect(samples.count == 2)   // flow + bbt only
    }

    @Test("an empty log produces no samples")
    func emptyLogNoSamples() {
        #expect(HealthKitFieldMapping.samples(for: DailyLog(date: day), isPeriodStart: false).isEmpty)
    }

    @Test("ingesting a menstrual-flow sample sets the flow field")
    func ingestFlow() throws {
        // HealthKit requires the cycle-start metadata on every menstrualFlow sample.
        let sample = HKCategorySample(
            type: HKCategoryType(.menstrualFlow),
            value: HKCategoryValueMenstrualFlow.heavy.rawValue,
            start: day, end: day,
            metadata: [HKMetadataKeyMenstrualCycleStart: false]
        )
        let updated = try #require(HealthKitFieldMapping.apply(sample, to: DailyLog(date: day)))
        #expect(updated.flow == .heavy)
    }
}

@Suite("HealthKit anchor persistence")
struct HealthKitAnchorTests {

    @Test("an anchor survives archive → unarchive")
    func anchorRoundTrip() throws {
        let anchor = HKQueryAnchor(fromValue: 42)
        let data = try #require(HealthKitAnchorStore.encode(anchor))
        let decoded = try #require(HealthKitAnchorStore.decode(data))
        // HKQueryAnchor re-archives to identical bytes when equal.
        #expect(HealthKitAnchorStore.encode(decoded) == data)
    }

    @Test("store persists and reloads per-type anchors independently")
    func perTypeStorage() {
        let defaults = UserDefaults(suiteName: "hk.tests.\(UUID().uuidString)")!
        let store = HealthKitAnchorStore(defaults: defaults)
        let flowID = HKCategoryType(.menstrualFlow).identifier
        let bbtID = HKQuantityType(.basalBodyTemperature).identifier

        #expect(store.anchor(for: flowID) == nil)
        store.setAnchor(HKQueryAnchor(fromValue: 7), for: flowID)
        #expect(store.anchor(for: flowID) != nil)
        #expect(store.anchor(for: bbtID) == nil)   // independent key
    }
}
