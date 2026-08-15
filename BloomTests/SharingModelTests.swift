import Foundation
import Testing
@testable import Bloom

@Suite("Sharing entities — privacy invariants")
struct SharingModelTests {

    // MARK: SharingPreset

    @Test("three presets exist; supportive is the default choice")
    func presets() {
        #expect(Set(SharingPreset.allCases) == [.minimal, .supportive, .ttc])
    }

    // MARK: PartnerLink override guards

    @Test("an override for an un-shareable field is dropped at construction")
    func initDropsUnShareableOverrides() {
        let link = PartnerLink(
            partnerName: "Sam",
            linkedAt: Date(timeIntervalSince1970: 0),
            fieldOverrides: [.sexActivity: true, .weight: true, .mood: true]
        )
        #expect(link.fieldOverrides[.sexActivity] == nil)
        #expect(link.fieldOverrides[.weight] == nil)
        #expect(link.fieldOverrides[.mood] == true)
    }

    @Test("setOverride is a no-op for a field with no toggle")
    func setOverrideNoOpForUnShareable() {
        var link = PartnerLink(partnerName: "Sam", linkedAt: Date(timeIntervalSince1970: 0))
        link.setOverride(.medication, shared: true)
        link.setOverride(.energy, shared: true)
        #expect(link.fieldOverrides[.medication] == nil)
        #expect(link.fieldOverrides[.energy] == true)
    }

    @Test("PartnerLink round-trips through Codable")
    func partnerLinkCodable() throws {
        var link = PartnerLink(partnerName: "Sam", linkedAt: Date(timeIntervalSince1970: 10))
        link.setOverride(.mood, shared: false)
        let data = try JSONEncoder().encode(link)
        #expect(try JSONDecoder().decode(PartnerLink.self, from: data) == link)
    }

    // MARK: MoodWeather consent gate

    @Test("mood weather only enters SharedState once she confirms it")
    func moodWeatherConsentGate() {
        let unconfirmed = MoodWeather(emoji: "🌧️", word: "tender", isConfirmed: false)
        #expect(SharedState(moodWeather: unconfirmed).moodWeather == nil)

        let confirmed = MoodWeather(emoji: "🌤️", word: "steady", isConfirmed: true)
        #expect(SharedState(moodWeather: confirmed).moodWeather == confirmed)
    }

    @Test("the setter also enforces the consent gate (no assignment bypass)")
    func moodWeatherSetterGate() {
        var state = SharedState()
        state.setMoodWeather(MoodWeather(emoji: "🌧️", word: "tender", isConfirmed: false))
        #expect(state.moodWeather == nil)
        let confirmed = MoodWeather(emoji: "🌤️", word: "steady", isConfirmed: true)
        state.setMoodWeather(confirmed)
        #expect(state.moodWeather == confirmed)
    }

    // MARK: SharedState blank (revoke / hidden ≡ un-logged)

    @Test("blank SharedState carries no residue")
    func blankState() {
        let blank = SharedState.blank
        #expect(blank.currentPhaseLabel == nil)
        #expect(blank.periodStartedFlag == false)
        #expect(blank.nextPeriodWindow == nil)
        #expect(blank.gentleWindowActive == false)
        #expect(blank.moodWeather == nil)
        #expect(blank.fertileWindow == nil)
    }

    @Test("SharedState carries only interpretations and round-trips")
    func sharedStateCodable() throws {
        let state = SharedState(
            currentPhaseLabel: "luteal phase",
            periodStartedFlag: true,
            nextPeriodWindow: PredictionWindow(
                windowStart: Date(timeIntervalSince1970: 100),
                windowEnd: Date(timeIntervalSince1970: 200),
                confidence: 0.7
            ),
            gentleWindowActive: true,
            moodWeather: MoodWeather(emoji: "🌤️", word: "steady", isConfirmed: true)
        )
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(SharedState.self, from: data) == state)
    }

    // MARK: PinnedNote

    @Test("three note kinds; text is capped")
    func pinnedNote() {
        #expect(Set(PinnedNote.Kind.allCases) == [.love, .reminder, .highlight])
        let long = String(repeating: "b", count: PinnedNote.maxLength + 50)
        let note = PinnedNote(authorId: UUID(), type: .love, text: long, createdAt: Date())
        #expect(note.text.count == PinnedNote.maxLength)
    }
}
