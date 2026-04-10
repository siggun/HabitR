import SwiftUI

// Compact contribution grid shown inside habit cards on the home screen
// Days of the week go left to right (Sun-Sat), weeks stack top to bottom
struct MiniGridView: View {
    let habit: Habit

    // Show ~6 weeks of data — fits nicely inside a card
    private let weeksToShow = 6
    private let cellSize: CGFloat = 8
    private let cellSpacing: CGFloat = 2

    var body: some View {
        // Each row is a week (Sun-Sat left to right), rows stack vertically
        VStack(spacing: cellSpacing) {
            ForEach(gridWeeks(), id: \.self) { week in
                HStack(spacing: cellSpacing) {
                    ForEach(week, id: \.self) { day in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(cellColor(for: day))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    // MARK: - Cell Color

    /// Solid on/off — completed = accent color, not completed = empty gray
    private func cellColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let isFuture = date > calendar.startOfDay(for: Date())

        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }

        let count = habit.completionCount(for: date)
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Generate week arrays — each inner array is one week (Sun-Sat)
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

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
