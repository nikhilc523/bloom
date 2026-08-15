import Foundation
import Testing
@testable import Bloom

@Suite("DailyLog + field enums")
struct DailyLogTests {

    // MARK: Enum completeness (every case from the data-model doc)

    @Test func flowCases() { #expect(Flow.allCases.count == 5) }
    @Test func moodCases() {
        #expect(Set(Mood.allCases) == [.calm, .happy, .irritable, .anxious, .low, .sensitive])
    }
    @Test func energyCases() { #expect(Energy.allCases.count == 3) }
    @Test func pmsCases() {
        #expect(Set(PMSSymptom.allCases) == [.bloating, .breastTenderness, .headache, .cravings])
    }
    @Test func sexActivityCases() {
        #expect(Set(SexActivity.allCases) == [.none, .protected, .unprotected])
    }
    @Test func bloodColorCases() {
        #expect(Set(BloodColor.allCases) == [.bright, .dark, .brown])
    }
    @Test func clotSizeCases() {
        #expect(Set(ClotSize.allCases) == [.none, .small, .large])
    }
    @Test func painLocationCases() {
        #expect(Set(PainLocation.allCases) == [.pelvic, .lowBack, .legRadiating, .oneSided])
    }
    @Test func cervicalMucusOrdered() {
        #expect(CervicalMucus.allCases == [.dry, .sticky, .creamy, .eggwhite])
        #expect(CervicalMucus.dry < CervicalMucus.eggwhite)
    }
    @Test func cervicalPositionOrdered() {
        #expect(CervicalPosition.firmLowClosed < CervicalPosition.softHighOpen)
    }
    @Test func lhTestCases() {
        #expect(Set(LHTest.allCases) == [.negative, .positive])
    }

    // MARK: Value-type clamping / construction

    @Test("cramp severity clamps into 0...10", arguments: [(-3, 0), (0, 0), (7, 7), (10, 10), (99, 10)])
    func crampClamps(_ input: Int, _ expected: Int) {
        #expect(CrampSeverity(input).value == expected)
    }

    @Test("BBT carries its unit")
    func bbtUnit() {
        #expect(BasalBodyTemperature(98.6, .fahrenheit).unit == .fahrenheit)
    }

    // MARK: Note privacy gate

    @Test("a public note exposes shareable text; a Private note never does")
    func notePrivacyGate() {
        #expect(Note(text: "feeling good").shareableText == "feeling good")
        #expect(Note(text: "secret", isPrivate: true).shareableText == nil)
    }

    @Test("note text is capped")
    func noteCapped() {
        let long = String(repeating: "a", count: Note.maxLength + 500)
        #expect(Note(text: long).text.count == Note.maxLength)
    }

    // MARK: DailyLog defaults + round-trip

    @Test("a fresh log has all fields empty (hidden ≡ un-logged)")
    func emptyLog() {
        let log = DailyLog(date: Date(timeIntervalSince1970: 0))
        #expect(log.flow == nil)
        #expect(log.mood.isEmpty)
        #expect(log.medications.isEmpty)
        #expect(log.weight == nil)
        #expect(log.note == nil)
    }

    @Test("a fully-populated DailyLog round-trips through Codable")
    func codableRoundTrip() throws {
        let log = DailyLog(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            flow: .medium,
            crampSeverity: CrampSeverity(6),
            mood: [.anxious, .low],
            energy: .low,
            pms: [.bloating, .cravings],
            sexActivity: .protected,
            bloodColor: .dark,
            clotSize: .large,
            painLocation: [.pelvic, .oneSided],
            bbt: BasalBodyTemperature(36.7, .celsius),
            cervicalMucus: .eggwhite,
            cervicalPosition: .softHighOpen,
            lhTest: .positive,
            medications: [Medication(name: "Iron", type: .supplement, taken: true)],
            discharge: Discharge(type: .white, hasOdor: false, hasItch: true),
            digestion: .bloated,
            headache: .moderate,
            cravings: [.sweet],
            skin: .acne,
            sleepQuality: .poor,
            weight: BodyWeight(61.2, .kilograms),
            waterIntake: 6,
            libido: .low,
            note: Note(text: "long day", isPrivate: true)
        )
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(DailyLog.self, from: data)
        #expect(decoded == log)
    }
}
