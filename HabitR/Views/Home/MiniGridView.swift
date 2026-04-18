import SwiftUI

/// Compact contribution grid rendered inside each `HabitCardView` on the home screen.
///
/// Layout: 7 columns (Sun→Sat), `weeksToShow` rows (oldest week on top). Cell size is derived
/// from the available card width via `GeometryReader`, so the grid always fills its parent edge
/// to edge without manual sizing per device.
///
/// ## Color semantics
/// Three visual states, mapped in `cellColor(for:)`:
/// | State                         | Color             | Meaning                              |
/// | ----------------------------- | ----------------- | ------------------------------------ |
/// | Day with a completion         | `Color.accentColor` | Habit was performed that day        |
/// | Future day or pre-creation day | `Color(.systemGray5)` | "Not applicable" — don't count as a miss |
/// | In-range day with no completion | `Color(.systemGray6)` | Missed day                          |
///
/// > **Known contrast issue (dark mode):** the card's background is
/// > `Color(.systemGray6).opacity(0.5)` over the app's near-black background. `systemGray6`
/// > renders *almost identical* to that stack, so missed-day cells visually disappear into the
/// > card. This is why some grids on dark mode look "blacked out" at the bottom. Cells painted
/// > `systemGray5` (future / pre-creation) are lighter and remain visible. Fixing this means
/// > picking a distinct in-range-empty tone or tweaking the card background alpha.
struct MiniGridView: View {
    let habit: Habit

    /// Six weeks ≈ 42 days — enough history for the card to show meaningful streaks without
    /// crowding the compact layout. Full history lives on the detail view's `GridView`.
    private let weeksToShow = 6

    /// Inter-cell gutter in points. Small value preserves the "dense grid" aesthetic of the
    /// GitHub contribution graph that inspired this visualization.
    private let cellSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            // [Interview] Solve for cellSize so 7 cells + 6 gutters exactly fill the width.
            // `max(0, …)` guards against a momentary negative width during layout (e.g. the
            // card animating in at zero size), which would otherwise crash `.frame(width:)`.
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
        // 7:6 aspect ratio gives SwiftUI's layout system a concrete height to reserve, which
        // is what lets the card lay itself out without collapsing to zero.
        .aspectRatio(7.0 / 6.0, contentMode: .fit)
    }

    // MARK: - Cell Color

    /// Decide the fill color for a single calendar day.
    ///
    /// See the class-level dark-mode contrast note — the `systemGray6` branch here is the source
    /// of the "disappearing missed-day cells" behavior on dark backgrounds.
    private func cellColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let isFuture = date > calendar.startOfDay(for: Date())

        // [Interview] Both "before creation" and "future" are rendered the same way — they're
        // conceptually "N/A" (the habit didn't exist, or the day hasn't happened). We use a
        // lighter gray so these read as placeholders rather than as misses.
        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }

        let count = habit.completionCount(for: date)
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Build a `[weeks][days]` matrix of calendar dates for the window this grid displays.
    ///
    /// Algorithm:
    /// 1. Anchor on the current week's Sunday (weekday == 1 in `Calendar.current`).
    /// 2. Step back `weeksToShow - 1` weeks to find the first date shown.
    /// 3. Walk forward day by day, packing 7-day rows.
    ///
    /// - Returns: `weeksToShow` rows of exactly 7 `Date` values, each normalized implicitly by
    ///   the calendar arithmetic (we never mutate the time-of-day component).
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // [Interview] `.weekday` is 1-indexed with Sunday = 1. Subtracting `weekday - 1` lands
        // us on the Sunday of the current week regardless of what day it is today.
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: today
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
                // [Interview] `?? currentDate` guards against Calendar returning nil for an
                // arithmetic operation — shouldn't happen for +1 day, but nil-coalescing keeps
                // the loop making progress rather than infinite-looping on the same date.
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            weeks.append(week)
        }

        return weeks
    }
}
