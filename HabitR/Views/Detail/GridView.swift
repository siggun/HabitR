import SwiftUI

// GitHub-style contribution grid — the signature visual of the app
// Days of the week go left to right (Sun-Sat), weeks stack top to bottom
// Shows the last ~18 weeks of data in a scrollable grid
struct GridView: View {
    let habit: Habit

    // Number of weeks to show (roughly 4 months)
    private let weeksToShow = 18
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    // Day-of-week labels shown on the left column
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Day-of-week header labels (horizontal)
                    dayHeaderRow

                    // Grid of day cells — each row is a week
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

            // Legend showing completed vs not
            legendView
                .padding(.horizontal)
        }
    }

    // MARK: - Day Header

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

    /// A single cell in the grid — solid color for completed, empty for not
    private func gridCell(for date: Date) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .frame(width: cellSize, height: cellSize)
    }

    /// Solid on/off — completed = accent color, not completed = empty gray
    private func cellColor(count: Int, isBeforeCreation: Bool, isFuture: Bool) -> Color {
        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Generate the grid data — an array of weeks, each containing 7 days
    /// Each row is a week (Sun-Sat), arranged top to bottom (oldest first)
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start of this week (Sunday)
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: today
        ) else { return [] }

        // Go back weeksToShow weeks
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

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 6) {
            Spacer()

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray6))
                .frame(width: cellSize, height: cellSize)
            Text("Not done")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: cellSize, height: cellSize)
            Text("Done")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
