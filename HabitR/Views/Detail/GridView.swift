import SwiftUI

// GitHub-style contribution grid — the signature visual of the app
// Each square represents one day, with color intensity based on completion count
// Shows the last ~4 months of data in a scrollable grid
struct GridView: View {
    let habit: Habit

    // Number of weeks to show (roughly 4 months)
    private let weeksToShow = 18
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    // Days of the week labels
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Day-of-week labels on the left
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { day in
                            Text(dayLabels[day])
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: cellSize)
                        }
                    }

                    // Grid of day cells
                    HStack(spacing: cellSpacing) {
                        ForEach(gridWeeks(), id: \.self) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(week, id: \.self) { day in
                                    gridCell(for: day)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Legend showing intensity levels
            legendView
                .padding(.horizontal)
        }
    }

    // MARK: - Grid Cell

    /// A single cell in the grid — color intensity maps to completion count
    private func gridCell(for date: Date) -> some View {
        let count = habit.completionCount(for: date)
        let isBeforeCreation = date < Calendar.current.startOfDay(for: habit.createdAt)
        let isFuture = date > Calendar.current.startOfDay(for: Date())

        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(count: count, isBeforeCreation: isBeforeCreation, isFuture: isFuture))
            .frame(width: cellSize, height: cellSize)
    }

    /// Map a completion count to a color intensity
    /// 0 = empty, 1 = light green, 2+ = progressively darker
    private func cellColor(count: Int, isBeforeCreation: Bool, isFuture: Bool) -> Color {
        if isBeforeCreation || isFuture {
            return Color(.systemGray5)
        }

        let target = max(habit.dailyTarget, 1)

        switch count {
        case 0:
            return Color(.systemGray6)
        case 1 where target == 1:
            // Toggle mode or counter with target 1 — full color on completion
            return Color.accentColor
        default:
            // Counter mode — intensity scales with progress toward target
            let ratio = min(Double(count) / Double(target), 1.5)
            let opacity = 0.2 + (0.8 * min(ratio, 1.0))
            return Color.accentColor.opacity(opacity)
        }
    }

    // MARK: - Grid Data

    /// Generate the grid data — an array of weeks, each containing 7 days
    /// Arranged so the most recent week is on the right
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
        HStack(spacing: 4) {
            Spacer()
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(legendColor(level: level))
                    .frame(width: cellSize, height: cellSize)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func legendColor(level: Int) -> Color {
        switch level {
        case 0: return Color(.systemGray6)
        case 1: return Color.accentColor.opacity(0.3)
        case 2: return Color.accentColor.opacity(0.5)
        case 3: return Color.accentColor.opacity(0.75)
        case 4: return Color.accentColor
        default: return Color.accentColor
        }
    }
}
