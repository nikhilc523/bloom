#if DEBUG
import SwiftUI

/// A live catalog of every pink-glass component — for eyeballing the design system
/// in the running Simulator. **DEBUG-only and gated behind the `-designGallery`
/// launch argument** (see `BloomApp`), so it can never reach a release build or the
/// real app. Not shipped, not tested; delete freely once real screens exist.
struct DesignGallery: View {
    @State private var day = "Today"
    @State private var tab = "home"
    @State private var checked = false
    @State private var checked2 = true
    @State private var ask = ""

    private let august = DateComponents(calendar: .current, year: 2026, month: 8, day: 1).date!

    var body: some View {
        ZStack {
            Bloom.Background()

            ScrollView {
                VStack(spacing: 28) {
                    section("Cycle Ring") {
                        CycleRing(day: 12, length: 28)
                    }

                    section("Hero Number") {
                        HeroNumber(value: "12", caption: "Follicular", eyebrow: "Day")
                    }

                    section("Mood Weather") {
                        MoodWeatherTile(mood: .cloudy, phase: .luteal)
                    }

                    section("Phase Card (tap to expand)") {
                        PhaseCard(
                            phase: .luteal,
                            summary: "You're in your luteal phase — cravings and lower energy are normal now.",
                            tips: ["Go easy on caffeine", "A short walk helps the mood dip"]
                        )
                    }

                    section("Pastel Chips") {
                        HStack(spacing: 10) {
                            PastelChip(text: "Log period", role: .action, icon: "drop.fill")
                            PastelChip(text: "Insight", role: .info, icon: "sparkles")
                            PastelChip(text: "Luteal", role: .phase(.luteal))
                        }
                    }

                    section("Segmented Pills") {
                        SegmentedPills(
                            options: ["Today", "Tue", "Wed", "Thu", "Fri"],
                            selection: $day,
                            label: { $0 }
                        )
                    }

                    section("Checklist Rows") {
                        VStack(spacing: 12) {
                            ChecklistRow(title: "Log today's flow", subtitle: "Takes 5 seconds", isDone: checked) {
                                checked.toggle()
                            }
                            ChecklistRow(title: "Connect Apple Health", isDone: checked2) {
                                checked2.toggle()
                            }
                        }
                    }

                    section("Floating Pinned Note / Pill Row") {
                        VStack(spacing: 12) {
                            FloatingPinnedNote(
                                title: "Period likely tomorrow",
                                subtitle: "Maybe pack a few things 💗",
                                onTap: {}
                            )
                            FloatingPillRow(icon: "sparkles", title: "Headaches cluster on days 26–28", subtitle: "Insight") {
                                PastelChip(text: "See", role: .info)
                            }
                        }
                    }

                    section("Calendar") {
                        CalendarGrid(
                            month: august,
                            periodDays: [3, 4, 5, 6, 7],
                            predictedDays: [30, 31],
                            todayDay: 15
                        )
                    }

                    section("Glass Input Pill") {
                        GlassInputPill(placeholder: "Ask Bloom anything…", text: $ask) { ask = "" }
                    }

                    section("Glass Tab Bar") {
                        GlassTabBar(
                            items: [
                                .init(tab: "home", title: "Home", icon: "house"),
                                .init(tab: "calendar", title: "Calendar", icon: "calendar"),
                                .init(tab: "insights", title: "Insights", icon: "sparkles"),
                            ],
                            selection: $tab
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Bloom.Typography.caption.weight(.semibold))
                .foregroundStyle(Bloom.Palette.mist)
                .textCase(.uppercase)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DesignGallery()
}
#endif
