import SwiftUI

// GitHub-style contribution grid — the signature visual of the app
// Days of the week go left to right (Sun-Sat), weeks stack top to bottom.
// Uses LazyVGrid with flexible columns so cells automatically scale to
// fill the full width of whatever container GridView is placed in.
struct GridView: View {
    let habit: Habit

    // Number of weeks to show (roughly 4 months)
    private let weeksToShow = 18
    private let cellSpacing: CGFloat = 4

    // Day-of-week labels shown in the header row
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // 7 flexible columns — one per day of the week. LazyVGrid splits the
    // available width evenly across them, so cells always fill the screen.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: cellSpacing) {
                dayHeaderRow
                contributionGrid
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Day Header

    /// 7 labels distributed evenly with the same spacing as the grid below,
    /// so each label lines up with the column underneath it.
    private var dayHeaderRow: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { day in
                Text(dayLabels[day])
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var contributionGrid: some View {
        LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(gridDays(), id: \.self) { day in
                gridCell(for: day)
            }
        }
    }

    /// A single cell — square via aspectRatio so rows match column width
    private func gridCell(for date: Date) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 4)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .aspectRatio(1, contentMode: .fit)
    }

    /// Solid on/off — completed = accent color, not completed = empty gray.
    /// Before-creation and future days use a very faint fill so they recede
    /// instead of looking like a distinct "unavailable" state.
    private func cellColor(count: Int, isBeforeCreation: Bool, isFuture: Bool) -> Color {
        if isBeforeCreation || isFuture {
            return Color(.systemGray6).opacity(0.4)
        }
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Flat array of dates for the grid (oldest first), one per cell.
    /// Starts at the Sunday `weeksToShow - 1` weeks ago, ends at this Saturday.
    private func gridDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start of this week (Sunday)
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: today
        ) else { return [] }

        // Walk back weeksToShow weeks
        guard let gridStart = calendar.date(
            byAdding: .weekOfYear, value: -(weeksToShow - 1), to: startOfWeek
        ) else { return [] }

        var days: [Date] = []
        var currentDate = gridStart

        for _ in 0..<(weeksToShow * 7) {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }
}
