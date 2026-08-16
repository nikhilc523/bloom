import SwiftUI

/// A minimal month grid — logged period days as solid Rose dots, predicted days
/// as dashed/ghost dots (uncertainty made visual, docs/research/05-ai-and-design.md
/// §B5.5). Pure and deterministic: it takes the days to mark, it does not read the
/// clock, so it snapshots reliably.
struct CalendarGrid: View {
    /// First day of the month to render.
    let month: Date
    /// Day-of-month numbers logged as period days (solid Rose).
    var periodDays: Set<Int> = []
    /// Day-of-month numbers predicted as period days (dashed ghost).
    var predictedDays: Set<Int> = []
    /// Day-of-month to highlight as "today" (optional, e.g. injected for tests).
    var todayDay: Int?

    var calendar: Calendar = .current

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthComponents: DateComponents {
        calendar.dateComponents([.year, .month], from: month)
    }

    /// Weekday index (0=Sun) of the 1st, used to pad the leading blanks.
    private var leadingBlanks: Int {
        guard let first = calendar.date(from: monthComponents) else { return 0 }
        return calendar.component(.weekday, from: first) - calendar.firstWeekday
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthTitle)
                .font(Bloom.Typography.title)
                .foregroundStyle(Bloom.Palette.plumInk)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdaySymbols[(i + calendar.firstWeekday - 1) % 7])
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Bloom.Palette.mist)
                }
                ForEach(0..<max(0, leadingBlanks), id: \.self) { _ in
                    Color.clear.frame(height: 34)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(20)
        .glassPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendarGrid")
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isPeriod = periodDays.contains(day)
        let isPredicted = predictedDays.contains(day)
        let isToday = todayDay == day

        Text("\(day)")
            .font(Bloom.Typography.caption)
            .foregroundStyle(isPeriod ? .white : Bloom.Palette.plumInk)
            .frame(width: 34, height: 34)
            .background(dayBackground(isPeriod: isPeriod, isPredicted: isPredicted))
            .overlay(
                Circle()
                    .strokeBorder(Bloom.Palette.deepRose, lineWidth: isToday ? 1.5 : 0)
            )
            .accessibilityLabel("\(day)")
            .accessibilityValue(cellState(isPeriod: isPeriod, isPredicted: isPredicted, isToday: isToday))
            .accessibilityIdentifier("calendarDay.\(day)")
    }

    @ViewBuilder
    private func dayBackground(isPeriod: Bool, isPredicted: Bool) -> some View {
        if isPeriod {
            // Solid Rose dot — a logged, certain period day.
            Circle().fill(Bloom.Palette.rose)
        } else if isPredicted {
            // Dashed ghost dot — predicted, uncertain. Never a certainty.
            Circle()
                .fill(Bloom.Palette.rose.opacity(0.10))
                .overlay(
                    Circle().stroke(
                        Bloom.Palette.rose.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])
                    )
                )
        } else {
            Circle().fill(.clear)
        }
    }

    private func cellState(isPeriod: Bool, isPredicted: Bool, isToday: Bool) -> String {
        var parts: [String] = []
        if isPeriod { parts.append("period day") }
        else if isPredicted { parts.append("predicted period day") }
        if isToday { parts.append("today") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ZStack {
        Bloom.Background()
        CalendarGrid(
            month: DateComponents(calendar: .current, year: 2026, month: 8, day: 1).date!,
            periodDays: [3, 4, 5, 6, 7],
            predictedDays: [30, 31],
            todayDay: 15
        )
        .padding()
    }
}
