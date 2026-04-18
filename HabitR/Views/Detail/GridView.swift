import SwiftUI

/// Full contribution grid rendered on `HabitDetailView` — the app's signature visual.
///
/// Same conceptual layout as `MiniGridView` (7 columns Sun→Sat, weeks stacked vertically) but
/// shows a longer history (~18 weeks ≈ 4 months) at a fixed cell size instead of adapting to
/// parent width. Fixed sizing is used here because the detail screen is already horizontally
/// padded inside a `ScrollView`, and we want cells to render at a legible, consistent size
/// across devices rather than stretching on iPad.
///
/// > **Shared dark-mode contrast caveat:** see the class-level note on `MiniGridView`. The
/// > `cellColor(count:isBeforeCreation:isFuture:)` method duplicates the same color logic, so
/// > the same "disappearing missed-day cells on dark backgrounds" behavior applies here. Any
/// > fix should be applied to both views in lockstep.
struct GridView: View {
    let habit: Habit

    /// ~4 months of history — enough to visualize seasonal patterns without introducing
    /// horizontal scrolling.
    private let weeksToShow = 18

    /// Fixed cell edge length in points. Chosen to feel readable on iPhone SE without being
    /// sparse on Pro Max.
    private let cellSize: CGFloat = 14

    /// Inter-cell gutter. Slightly larger than `MiniGridView`'s because cells are bigger.
    private let cellSpacing: CGFloat = 3

    /// Day-of-week header labels. Two "T" and two "S" are intentional (Tue/Thu and Sat/Sun
    /// share initials) — matches Apple's own calendar conventions.
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            // [Interview] No inner ScrollView intentionally — `HabitDetailView` wraps this in
            // its own ScrollView. Nesting two vertically-scrolling scroll views would hijack
            // gestures and produce a subtle "scroll doesn't release" bug that's painful to
            // diagnose. Keeping this flat delegates all scrolling to the parent.
            VStack(alignment: .leading, spacing: 0) {
                dayHeaderRow

                VStack(spacing: cellSpacing) {
                    ForEach(gridWeeks(), id: \.self) { week in
                        HStack(spacing: cellSpacing) {
                            ForEach(week, id: \.self) { day in
                                gridCell(for: day)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Day Header

    /// Row of day-of-week initials rendered above the grid. Cell-width-matched so each letter
    /// aligns vertically with its column.
    private var dayHeaderRow: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { day in
                Text(dayLabels[day])
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, height: 16)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Grid Cell

    /// Build a single cell view. Branches the color decision into a pure helper so the logic is
    /// easy to unit-test if a color scheme refactor ever happens.
    private func gridCell(for date: Date) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .frame(width: cellSize, height: cellSize)
    }

    /// Color policy (mirrors `MiniGridView`):
    /// - future / pre-creation → `systemGray5` (visibly lighter placeholder)
    /// - completed             → accent color
    /// - in-range, not done    → `systemGray6` (dark-mode contrast caveat — see class doc)
    private func cellColor(count: Int, isBeforeCreation: Bool, isFuture: Bool) -> Color {
        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Produce `weeksToShow` weeks of dates, oldest first. Logic mirrors `MiniGridView.gridWeeks()`
    /// — kept duplicated (rather than extracted) because the two views diverge on sizing and
    /// history length, and an abstraction would mostly be parameter-shuffling.
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // [Interview] Same anchor trick as MiniGridView: back up to the Sunday of this week,
        // then back up N-1 weeks to get the grid's first day.
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
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            weeks.append(week)
        }

        return weeks
    }
}
