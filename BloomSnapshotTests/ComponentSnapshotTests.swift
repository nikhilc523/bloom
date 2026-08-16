import Testing
import SwiftUI
import SnapshotTesting
@testable import Bloom

/// Pixel-diff lock for the pink-glass component library. RECORDED on the pinned
/// device — iPhone 17, iOS 26.3 — because frosted-glass/blur rendering differs
/// across devices/OS. CI pins the same destination (see .github/workflows/ci.yml)
/// so these stay stable. A small perceptual tolerance absorbs AA jitter across OS
/// point releases. To intentionally re-record after a design change, flip
/// `record: .all` locally, run once, and commit the new PNGs.
@MainActor
struct ComponentSnapshotTests {

    /// The OS the reference PNGs were recorded on. Frosted-glass/blur and font
    /// metrics differ across major OS versions, so the pixel diff only makes sense
    /// on a matching renderer. On any other OS (e.g. a CI runner still on iOS 18)
    /// we skip the pixel assert — the ViewInspector suite is the universal lock —
    /// so environment drift can never red CI. Re-record if this bumps.
    private static let referenceOSMajor = 26

    private var onReferenceOS: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == Self.referenceOSMajor
    }

    /// Frame a component over the ambient pink field and snapshot it light + dark.
    private func assertGlass(
        _ view: some View,
        size: CGSize,
        testName: String = #function,
        line: UInt = #line,
        file: StaticString = #filePath
    ) {
        guard onReferenceOS else { return } // logic tests still lock structure everywhere
        let framed = ZStack {
            Bloom.Background()
            view.padding()
        }
        .frame(width: size.width, height: size.height)

        for style: UIUserInterfaceStyle in [.light, .dark] {
            assertSnapshot(
                of: framed,
                as: .image(
                    precision: 0.99,
                    perceptualPrecision: 0.97,
                    layout: .fixed(width: size.width, height: size.height),
                    traits: .init(userInterfaceStyle: style)
                ),
                named: style == .dark ? "dark" : "light",
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func cycleRing() {
        assertGlass(CycleRing(day: 12, length: 28), size: CGSize(width: 320, height: 320))
    }

    @Test func heroNumber() {
        assertGlass(
            HeroNumber(value: "12", caption: "Follicular", eyebrow: "Day"),
            size: CGSize(width: 320, height: 220)
        )
    }

    @Test func phaseCard() {
        assertGlass(
            PhaseCard(
                phase: .luteal,
                summary: "You're in your luteal phase — cravings and lower energy are normal now.",
                tips: ["Go easy on caffeine", "A short walk helps"]
            ),
            size: CGSize(width: 390, height: 260)
        )
    }

    @Test func moodWeatherTile() {
        assertGlass(
            MoodWeatherTile(mood: .cloudy, phase: .luteal),
            size: CGSize(width: 320, height: 240)
        )
    }

    @Test func floatingPinnedNote() {
        assertGlass(
            FloatingPinnedNote(title: "Period likely tomorrow", subtitle: "Maybe pack a few things 💗"),
            size: CGSize(width: 390, height: 160)
        )
    }

    @Test func calendarGrid() {
        let august = DateComponents(calendar: .current, year: 2026, month: 8, day: 1).date!
        assertGlass(
            CalendarGrid(month: august, periodDays: [3, 4, 5, 6, 7], predictedDays: [30, 31], todayDay: 15),
            size: CGSize(width: 390, height: 420)
        )
    }

    @Test func pastelChips() {
        assertGlass(
            VStack(spacing: 12) {
                PastelChip(text: "Log period", role: .action, icon: "drop.fill")
                PastelChip(text: "Insight", role: .info, icon: "sparkles")
                PastelChip(text: "Luteal", role: .phase(.luteal))
            },
            size: CGSize(width: 320, height: 220)
        )
    }

    @Test func checklistRow() {
        assertGlass(
            VStack(spacing: 12) {
                ChecklistRow(title: "Log today's flow", subtitle: "Takes 5 seconds", isDone: false) {}
                ChecklistRow(title: "Connect Apple Health", isDone: true) {}
            },
            size: CGSize(width: 390, height: 220)
        )
    }

    /// Dynamic Type audit — the text-heavy card must stay readable and not clip at
    /// an accessibility size. Locks the DoD's "Dynamic-Type audited" line.
    @Test func phaseCardAccessibilityExtraLarge() {
        guard onReferenceOS else { return }
        let framed = ZStack {
            Bloom.Background()
            PhaseCard(
                phase: .luteal,
                summary: "You're in your luteal phase — cravings and lower energy are normal now.",
                tips: ["Go easy on caffeine"]
            )
            .padding()
        }
        .frame(width: 390, height: 420)

        assertSnapshot(
            of: framed,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.97,
                layout: .fixed(width: 390, height: 420),
                traits: .init(preferredContentSizeCategory: .accessibilityExtraLarge)
            ),
            named: "axXL"
        )
    }

    @Test func glassTabBar() {
        assertGlass(
            GlassTabBar(
                items: [
                    .init(tab: "home", title: "Home", icon: "house"),
                    .init(tab: "calendar", title: "Calendar", icon: "calendar"),
                    .init(tab: "insights", title: "Insights", icon: "sparkles"),
                ],
                selection: .constant("home")
            ),
            size: CGSize(width: 390, height: 140)
        )
    }
}
