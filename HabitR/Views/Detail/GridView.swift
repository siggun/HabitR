import SwiftUI

// GitHub-style contribution grid — days of the week as rows on the left,
// weeks as columns scrolling horizontally. Day labels stay pinned on the
// left while the grid scrolls. Most recent week is on the right.
struct GridView: View {
    let habit: Habit

    private let weeksToShow = 20
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let labelWidth: CGFloat = 16

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 6) {
                // Pinned day-of-week labels on the left — these stay
                // visible while the grid scrolls horizontally.
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(dayLabels[row])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, height: cellSize)
                    }
                }

                // Horizontally scrollable grid of week columns
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cellSpacing) {
                        ForEach(gridColumns(), id: \.self) { column in
                            VStack(spacing: cellSpacing) {
                                ForEach(column, id: \.self) { day in
                                    gridCell(for: day)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Grid Cell

    private func gridCell(for date: Date) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .frame(width: cellSize, height: cellSize)
    }

    private func cellColor(count: Int, isBeforeCreation: Bool, isFuture: Bool) -> Color {
        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Returns an array of columns, each column being one week (7 days).
    /// Column 0 is the oldest week, last column is the current week.
    /// Within each column: index 0 = Sunday, index 6 = Saturday.
    private func gridColumns() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: today
        ) else { return [] }

        guard let gridStart = calendar.date(
            byAdding: .weekOfYear, value: -(weeksToShow - 1), to: startOfWeek
        ) else { return [] }

        var columns: [[Date]] = []
        var currentDate = gridStart

        for _ in 0..<weeksToShow {
            var column: [Date] = []
            for _ in 0..<7 {
                column.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            columns.append(column)
        }

        return columns
    }
}
