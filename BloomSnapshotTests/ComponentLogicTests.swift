import Testing
import SwiftUI
import ViewInspector
@testable import Bloom

/// Deterministic view-tree + token logic tests. These run on *any* simulator (no
/// pixels), so they are the CI-green safety net; the image snapshots
/// (`ComponentSnapshotTests`) add the pixel lock on the pinned device.
@MainActor
struct ComponentLogicTests {

    // MARK: - Token mappings (pure, rock-solid)

    @Test func phaseTintsAreDistinctAndPink() {
        let tints = [CyclePhase.menstrual, .follicular, .ovulation, .luteal]
            .map(Bloom.Palette.phaseTint)
        #expect(Set(tints.map { "\($0)" }).count == 4) // all four distinct
        #expect(Bloom.Palette.phaseTint(.menstrual) == Bloom.Palette.rose)
        #expect(Bloom.Palette.phaseTint(.ovulation) == Bloom.Palette.deepRose)
    }

    @Test func chipRoleColorsMatchTheOneAccentRule() {
        #expect(PastelChip.Role.action.tint == Bloom.Palette.deepRose)   // your action
        #expect(PastelChip.Role.info.tint == Bloom.Palette.periwinkle)   // the one non-pink
        #expect(PastelChip.Role.neutral.tint == Bloom.Palette.mist)
        #expect(PastelChip.Role.phase(.luteal).tint == Bloom.Palette.phaseTint(.luteal))
    }

    @Test func moodForecastMapsEveryPhase() {
        #expect(MoodForecast.forPhase(.menstrual) == .stormy)
        #expect(MoodForecast.forPhase(.follicular) == .sunny)
        #expect(MoodForecast.forPhase(.ovulation) == .partlyCloudy)
        #expect(MoodForecast.forPhase(.luteal) == .cloudy)
        // Every case has a symbol + caption (no empty charm moment).
        for mood in MoodForecast.allCases {
            #expect(!mood.symbol.isEmpty)
            #expect(!mood.caption.isEmpty)
        }
    }

    // MARK: - View-tree presence (ViewInspector)

    @Test func heroNumberShowsValueEyebrowAndCaption() throws {
        let sut = HeroNumber(value: "12", caption: "Follicular", eyebrow: "Day")
        #expect(throws: Never.self) { try sut.inspect().find(text: "12") }
        #expect(throws: Never.self) { try sut.inspect().find(text: "Day") }
        #expect(throws: Never.self) { try sut.inspect().find(text: "Follicular") }
    }

    @Test func phaseCardShowsPhaseAndSummary() throws {
        let sut = PhaseCard(phase: .luteal, summary: "Take it slow today.", tips: ["Rest"])
        #expect(throws: Never.self) { try sut.inspect().find(text: "Luteal phase") }
        #expect(throws: Never.self) { try sut.inspect().find(text: "Take it slow today.") }
    }

    @Test func calendarRendersAllDaysOfA31DayMonth() throws {
        let august = DateComponents(calendar: .current, year: 2026, month: 8, day: 1).date!
        let sut = CalendarGrid(month: august, periodDays: [3, 4, 5], predictedDays: [30, 31])
        // Title + the last day of a 31-day month both present.
        #expect(throws: Never.self) { try sut.inspect().find(text: "August 2026") }
        #expect(throws: Never.self) { try sut.inspect().find(text: "31") }
    }

    @Test func floatingPinnedNoteShowsTitleAndSubtitle() throws {
        let sut = FloatingPinnedNote(title: "Period likely tomorrow", subtitle: "Pack a few things")
        #expect(throws: Never.self) { try sut.inspect().find(text: "Period likely tomorrow") }
        #expect(throws: Never.self) { try sut.inspect().find(text: "Pack a few things") }
    }
}
