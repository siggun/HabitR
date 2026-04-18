import SwiftUI

/// Compact contribution grid rendered inside each `HabitCardView` on the home screen.
///
/// Layout: 7 columns (Mon→Sun), `weeksToShow` rows (oldest week on top). Cell size adapts to the
/// card's available width via `GeometryReader` so the grid fills its parent edge to edge.
/// Week order matches the detail-view `GridView` and the bottom `CalendarView` — every
/// time-based view in the app agrees on Monday as the start of the week.
///
/// ## Color policy (single-tone empty)
/// Every cell is one of two colors:
/// - `Color.gridAccent` — the day has a logged completion.
/// - `Color.gridMuted`  — every other state (missed, future, pre-creation).
///
/// Past versions of this view tried to distinguish "missed in-range" from "future / pre-creation"
/// using `systemGray6` vs `systemGray5`. On dark backgrounds, `systemGray6` collapsed into the
/// near-black card fill and the missed-day cells became invisible. The fix was to pick one
/// readable empty tone and use it everywhere.
struct MiniGridView: View {
    let habit: Habit

    /// Six weeks ≈ 42 days — enough history for the card to show meaningful streaks without
    /// crowding the compact layout. Full history lives on the detail view's `GridView`.
    private let weeksToShow = 6

    /// Inter-cell gutter in points. Small value preserves the "dense grid" aesthetic.
    private let cellSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            // [Interview] Solve for cellSize so 7 cells + 6 gutters exactly fill the width.
            // `max(0, …)` guards against a momentary negative width during layout.
            let cellSize = max(0, (geo.size.width - cellSpacing * 6) / 7)

            VStack(spacing: cellSpacing) {
                ForEach(gridWeeks(), id: \.self) { week in
                    HStack(spacing: cellSpacing) {
                        ForEach(week, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: day))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, alignment: .topLeading)
        }
        // [Interview] GeometryReader has no intrinsic size — it fills its parent. Pinning a
        // 7:6 aspect ratio gives SwiftUI's layout system a concrete height to reserve.
        .aspectRatio(7.0 / 6.0, contentMode: .fit)
    }

    // MARK: - Cell Color

    /// Two-state coloring: filled on completion, empty otherwise. Future / pre-creation /
    /// missed days all render identically — we don't punish a missed day visually.
    private func cellColor(for date: Date) -> Color {
        habit.completionCount(for: date) > 0 ? .gridAccent : .gridMuted
    }

    // MARK: - Grid Data

    /// Build a `[weeks][days]` matrix of dates for the window this grid displays.
    /// Each row is a week (Mon→Sun), oldest week first.
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // [Interview] `.weekday` returns 1=Sun … 7=Sat. To land on the Monday of this week we
        // apply offset Sun→-6, Mon→0, Tue→-1, …, Sat→-5 — same trick used by `GridView`.
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: mondayOffset, to: today
        ) else { return [] }

        guard let gridStart = calendar.date(
            byAdding: .weekOfYear, value: -(weeksToShow - 1), to: startOfWeek
        ) else { return [] }

        var weeks: [[Date]] = []
        var currentDate = gridStart

        for _ in 0..<weeksToShow {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(currentDate)
                // [Interview] If Calendar arithmetic ever fails we break rather than reuse the
                // same date (which would produce a stuck cursor and an infinite-ish loop of
                // identical cells). An assertion fires in debug builds to surface the bug.
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    assertionFailure("Calendar failed to advance date")
                    return weeks
                }
                currentDate = next
            }
            weeks.append(week)
        }

        return weeks
    }
}
