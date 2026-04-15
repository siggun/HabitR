import SwiftUI

// Compact contribution grid shown inside habit cards on the home screen.
// Uses LazyVGrid with flexible columns so cells automatically scale to
// fill the full width of the card — no empty space on the right.
struct MiniGridView: View {
    let habit: Habit

    // Show ~6 weeks of data — fits nicely inside a card
    private let weeksToShow = 6
    private let cellSpacing: CGFloat = 2

    // 7 flexible columns — one per day of the week
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(gridDays(), id: \.self) { day in
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(for: day))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    // MARK: - Cell Color

    /// Solid on/off — completed = accent color, not completed = empty gray.
    /// Before-creation and future days recede into the background.
    private func cellColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let isFuture = date > calendar.startOfDay(for: Date())

        if isBeforeCreation || isFuture {
            return Color(.systemGray6).opacity(0.4)
        }

        let count = habit.completionCount(for: date)
        return count > 0 ? Color.accentColor : Color(.systemGray6)
    }

    // MARK: - Grid Data

    /// Flat array of dates for the grid (oldest first), one per cell
    private func gridDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(
            byAdding: .day, value: -(weekday - 1), to: today
        ) else { return [] }

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
