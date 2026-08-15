import Foundation
import Testing
@testable import Bloom

@Suite("Shareability — privacy invariants")
struct ShareabilityTests {

    // MARK: Field catalogue completeness

    @Test("every data-model field is catalogued")
    func fieldCatalogueComplete() {
        // The 24 fields from docs/product/01-data-model.md's DailyLog table.
        #expect(LogField.allCases.count == 24)
    }

    @Test("core vs advanced tiers match the spec")
    func tiers() {
        let core: Set<LogField> = [.flow, .crampSeverity, .mood, .energy, .pms, .sexActivity]
        for field in LogField.allCases {
            #expect(field.tier == (core.contains(field) ? .core : .advanced))
        }
    }

    // MARK: The un-shareable four (no toggle exists)

    @Test("exactly sex, medication, and weight are never-shareable fields")
    func neverShareableCatalogue() {
        #expect(Set(LogField.neverShareableFields) == [.sexActivity, .medication, .weight])
    }

    @Test("never-shareable fields have no toggle and can never reach the partner")
    func neverShareableHasNoToggle() {
        for field in LogField.neverShareableFields {
            #expect(field.shareability == .neverShareable)
            #expect(field.shareability.hasToggle == false)
            #expect(field.shareability.canEverReachPartner == false)
            #expect(field.shareability.isSharedByDefault == false)
        }
    }

    @Test("un-shareable value types conform to NeverShareable and NOT SharePermitted")
    func unShareableValueTypesAreStructurallyBlocked() {
        // If any of these could be treated as SharePermitted, the Stage-10
        // projection generic could accept them — a compile-time leak. Assert the
        // marker split holds at runtime too.
        let unShareable: [Any] = [
            SexActivity.unprotected,
            Medication(name: "x", type: .contraceptive, taken: true),
            BodyWeight(60, .kilograms),
        ]
        for value in unShareable {
            #expect(value is NeverShareable)
            #expect(!(value is SharePermitted))
        }
    }

    @Test("shareable value types conform to SharePermitted and NOT NeverShareable")
    func shareableValueTypesArePermitted() {
        let permitted: [Any] = [
            Flow.medium, CrampSeverity(4), Mood.calm, Energy.low, PMSSymptom.bloating,
            BloodColor.bright, ClotSize.large, PainLocation.pelvic,
            BasalBodyTemperature(36.5, .celsius), CervicalMucus.eggwhite,
            CervicalPosition.softHighOpen, LHTest.positive, Discharge(type: .white),
            Digestion.bloated, HeadacheSeverity.mild, Craving.sweet,
            SkinCondition.acne, SleepQuality.good, Libido.normal,
        ]
        for value in permitted {
            #expect(value is SharePermitted)
            #expect(!(value is NeverShareable))
        }
    }

    // MARK: Flow is the one default-shared field

    @Test("only flow is shared by default (as state)")
    func flowIsDefaultShared() {
        #expect(LogField.flow.shareability == .shareable)
        #expect(LogField.flow.shareability.isSharedByDefault)
        for field in LogField.allCases where field != .flow {
            #expect(field.shareability.isSharedByDefault == false)
        }
    }

    // MARK: ShareableEnvelope reports the wrapped type's shareability

    @Test("envelope surfaces the wrapped field's shareability")
    func envelopeShareability() {
        #expect(ShareableEnvelope(Energy.low).shareability == .softenedOptIn)
        #expect(ShareableEnvelope(Flow.spotting).shareability == .shareable)
    }

    // MARK: Enum round-trips

    @Test("Shareability and tiers are Codable round-trippable")
    func codableRoundTrip() throws {
        for value in Shareability.allCases {
            let data = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(Shareability.self, from: data) == value)
        }
    }
}
