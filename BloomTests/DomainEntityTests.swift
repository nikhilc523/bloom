import Foundation
import Testing
@testable import Bloom

@Suite("User + life-stage modes")
struct UserModelTests {
    @Test("seven life-stage modes")
    func modes() {
        #expect(LifeStageMode.allCases.count == 7)
    }

    @Test("pregnancy/postpartum/perimenopause suspend cycle prediction")
    func predictionValidity() {
        for mode in [LifeStageMode.cycle, .ttc, .birthControl, .teen] {
            #expect(mode.supportsCyclePrediction)
        }
        for mode in [LifeStageMode.pregnancy, .postpartum, .perimenopause] {
            #expect(mode.supportsCyclePrediction == false)
        }
    }

    @Test("teen mode widens the long-cycle bound to 45 days")
    func teenWidening() {
        #expect(LifeStageMode.teen.maxNormalCycleLength == 45)
        #expect(LifeStageMode.cycle.maxNormalCycleLength == 35)
    }

    @Test("User defaults to Supportive preset and clamps averages")
    func userDefaults() {
        let user = User(displayName: "A", onboardedAt: Date(timeIntervalSince1970: 0))
        #expect(user.sharingPreset == .supportive)
        #expect(user.lifeStageMode == .cycle)
        #expect(User(displayName: "A", avgCycleLength: 0, onboardedAt: Date()).avgCycleLength == 1)
    }

    @Test("User round-trips through Codable")
    func codable() throws {
        let user = User(
            displayName: "A",
            birthDate: Date(timeIntervalSince1970: -1_000_000),
            lifeStageMode: .ttc,
            onboardedAt: Date(timeIntervalSince1970: 0),
            sharingPreset: .ttc
        )
        let data = try JSONEncoder().encode(user)
        #expect(try JSONDecoder().decode(User.self, from: data) == user)
    }
}

@Suite("Cycle record + prediction")
struct CycleRecordTests {
    @Test("confidence values clamp into 0...1")
    func confidenceClamps() {
        #expect(OvulationEstimate(date: Date(), confidence: 2).confidence == 1)
        #expect(FertileWindow(start: Date(), end: Date(), confidence: -1).confidence == 0)
        #expect(PredictionWindow(
            windowStart: Date(), windowEnd: Date(), confidence: 5
        ).confidence == 1)
    }

    @Test("CycleRecord defaults to not-predicted with optional derived fields")
    func cycleRecordDefaults() {
        let cycle = CycleRecord(startDate: Date(timeIntervalSince1970: 0))
        #expect(cycle.isPredicted == false)
        #expect(cycle.endDate == nil)
        #expect(cycle.ovulationEstimate == nil)
    }

    @Test("prediction basis has three methods")
    func basis() {
        #expect(Set(PredictionBasis.allCases) == [.calendar, .bbt, .symptothermal])
    }

    @Test("Prediction round-trips through Codable")
    func predictionCodable() throws {
        let prediction = Prediction(
            nextPeriod: PredictionWindow(
                windowStart: Date(timeIntervalSince1970: 100),
                windowEnd: Date(timeIntervalSince1970: 300),
                confidence: 0.6
            ),
            basis: .symptothermal,
            generatedAt: Date(timeIntervalSince1970: 50)
        )
        let data = try JSONEncoder().encode(prediction)
        #expect(try JSONDecoder().decode(Prediction.self, from: data) == prediction)
    }
}

@Suite("ClinicalFlag — never a diagnosis")
struct ClinicalFlagTests {
    @Test("nine flag types")
    func types() { #expect(FlagType.allCases.count == 9) }

    @Test("severity is ordered informational < attention < urgent")
    func severityOrder() {
        #expect(FlagSeverity.informational < .attention)
        #expect(FlagSeverity.attention < .urgent)
    }

    @Test("a message without the clinician nudge gets it appended")
    func suffixAppended() {
        let flag = ClinicalFlag(
            type: .heavyBleeding,
            triggeredByRule: "period>7d",
            severity: .attention,
            message: "Your period has lasted more than 7 days",
            createdAt: Date()
        )
        #expect(flag.message.hasSuffix(ClinicalFlag.clinicianSuffix))
        #expect(ClinicalFlag.isClinicianSafe(flag.message))
    }

    @Test("an already-safe message is not double-suffixed")
    func noDoubleSuffix() {
        let message = "Something \(ClinicalFlag.clinicianSuffix)"
        let flag = ClinicalFlag(
            type: .urgent, triggeredByRule: "r", severity: .urgent,
            message: message, createdAt: Date()
        )
        #expect(flag.message == message)
        // Only one occurrence of the suffix.
        #expect(flag.message.components(separatedBy: ClinicalFlag.clinicianSuffix).count == 2)
    }

    @Test("trailing punctuation is trimmed before the nudge is joined")
    func trimsTrailingPunctuation() {
        let flag = ClinicalFlag(
            type: .irregularCycle, triggeredByRule: "shift>=7d", severity: .attention,
            message: "Your cycle length has been shifting.", createdAt: Date()
        )
        #expect(flag.message == "Your cycle length has been shifting \(ClinicalFlag.clinicianSuffix)")
    }
}
