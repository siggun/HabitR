import SwiftUI

// Compact contribution grid shown inside habit cards on the home screen
// Same algorithm as the full GridView but smaller and without labels or legend
struct MiniGridView: View {
    let habit: Habit

    // Show ~6 weeks of data — fits nicely inside a card
    private let weeksToShow = 6
    private let cellSize: CGFloat = 8
    private let cellSpacing: CGFloat = 2

    var body: some View {
        // No ScrollView needed — 6 weeks fits within the card width
        HStack(spacing: cellSpacing) {
            ForEach(gridWeeks(), id: \.self) { week in
                VStack(spacing: cellSpacing) {
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

    /// Map completion count to color intensity — same logic as GridView
    private func cellColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let isFuture = date > calendar.startOfDay(for: Date())

        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }

        let count = habit.completionCount(for: date)
        let target = max(habit.dailyTarget, 1)

        switch count {
        case 0:
            return Color(.systemGray6)
        case 1 where target == 1:
            return Color.accentColor
        default:
            let ratio = min(Double(count) / Double(target), 1.5)
            let opacity = 0.2 + (0.8 * min(ratio, 1.0))
            return Color.accentColor.opacity(opacity)
        }
    }

    // MARK: - Grid Data

    /// Generate week arrays — same algorithm as GridView.gridWeeks()
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
