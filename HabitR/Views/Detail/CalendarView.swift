import SwiftUI

// Month calendar view with tappable days for editing past completions
// Users can tap any past day to add or remove a completion
struct CalendarView: View {
    let habit: Habit
    let viewModel: HabitListViewModel

    @Environment(\.modelContext) private var modelContext

    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 12) {
            // Section title with hint
            HStack {
                Text("Calendar")
                    .font(.headline)
                Spacer()
                Text("Tap a day to mark complete")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Month navigation header
            monthHeader

            // Day-of-week labels
            dayOfWeekRow

            // Calendar grid
            calendarGrid
        }
        .padding(.horizontal)
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            // Disable forward navigation past current month
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Day Labels

    private var dayOfWeekRow: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = calendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                if let date = day {
                    dayCell(for: date)
                } else {
                    // Empty cell for padding at start/end of month
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
    }

    /// A single day cell — shows the day number with completion indicator
    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date())
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let count = habit.completionCount(for: date)
        let isCompleted = habit.isCompleted(for: date)

        return Button {
            handleDayTap(date: date)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isFuture || isBeforeCreation ? .tertiary : .primary)

                // Completion indicator dot/count
                if count > 0 {
                    if habit.completionMode == .counter {
                        Text("\(count)")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture || isBeforeCreation)
    }

    // MARK: - Actions

    private func handleDayTap(date: Date) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        if habit.completionMode == .toggle {
            viewModel.toggleCompletion(for: habit, on: date, context: modelContext)
        } else {
            // For counter mode in calendar, toggle between 0 and target
            let current = habit.completionCount(for: date)
            if current > 0 {
                viewModel.setCompletion(for: habit, on: date, count: 0, context: modelContext)
            } else {
                viewModel.setCompletion(for: habit, on: date, count: habit.dailyTarget, context: modelContext)
            }
        }
    }

    // MARK: - Helpers

    /// Generate array of optional dates for the calendar grid
    /// nil values represent empty cells before the first day or after the last day
    private func calendarDays() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }
}
