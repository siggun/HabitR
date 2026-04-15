import SwiftUI

// GitHub-style contribution grid — the signature visual of the app
// Days of the week go left to right (Sun-Sat), weeks stack top to bottom
// Cell size is calculated dynamically so the grid fills the full screen width
struct GridView: View {
    let habit: Habit

    // Number of weeks to show (roughly 4 months)
    private let weeksToShow = 18
    private let cellSpacing: CGFloat = 3

    // Day-of-week labels shown on the left column
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            // GeometryReader gives us the available width so we can size cells
            // to exactly fill the screen width (no empty space on the right)
            GeometryReader { geo in
                let totalSpacing = cellSpacing * 6 // 6 gaps between 7 cells
                let cellSize = floor((geo.size.width - totalSpacing) / 7)

                VStack(alignment: .leading, spacing: 0) {
                    dayHeaderRow(cellSize: cellSize)

                    VStack(spacing: cellSpacing) {
                        ForEach(gridWeeks(), id: \.self) { week in
                            HStack(spacing: cellSpacing) {
                                ForEach(week, id: \.self) { day in
                                    gridCell(for: day, size: cellSize)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: gridHeight())
            .padding(.horizontal)
        }
    }

    // MARK: - Day Header

    private func dayHeaderRow(cellSize: CGFloat) -> some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { day in
                Text(dayLabels[day])
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, height: 16)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Grid Cell

    /// A single cell in the grid — solid color for completed, empty for not
    private func gridCell(for date: Date, size: CGFloat) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .frame(width: size, height: size)
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

    // MARK: - Sizing

    /// Estimated total height so the GeometryReader container doesn't collapse.
    /// Uses the screen width to approximate what the dynamic cellSize will be.
    private func gridHeight() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = 32 // .padding(.horizontal) on both sides
        let available = screenWidth - horizontalPadding
        let estimatedCell = floor((available - (cellSpacing * 6)) / 7)
        let rows = CGFloat(weeksToShow)
        let headerHeight: CGFloat = 16 + 4 // header label + bottom padding
        return headerHeight + (rows * estimatedCell) + ((rows - 1) * cellSpacing)
    }
}
