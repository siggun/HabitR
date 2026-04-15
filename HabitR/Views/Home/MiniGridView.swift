import SwiftUI

// Compact contribution grid shown inside habit cards on the home screen.
// Days of the week go left to right (Sun-Sat), weeks stack top to bottom.
// Cell size is computed from the card's actual width via GeometryReader
// so the grid fills the full card width — no empty space on the right.
struct MiniGridView: View {
    let habit: Habit

    // Show ~6 weeks of data — fits nicely inside a card
    private let weeksToShow = 6
    private let cellSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            // Divide the card width evenly across 7 day columns
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
        // Claim exactly the right aspect ratio so the GeometryReader has a
        // concrete height. 7 columns × 6 rows ≈ 7:6 aspect ratio.
        .aspectRatio(7.0 / 6.0, contentMode: .fit)
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
