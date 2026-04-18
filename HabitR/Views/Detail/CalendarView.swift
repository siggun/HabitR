import SwiftUI

/// Month calendar surface for editing past completions.
///
/// Visual treatment matches the redesigned detail sheet:
/// - **Mon-first** weekday headers, matching the contribution grid above.
/// - **Completed day** → dark-green rounded pill behind the number, light-green dot below.
/// - **Today** → white circular outline (no fill) so it reads as "current" without competing
///   with the green completion pill if today happens to also be completed.
/// - **Adjacent-month days** rendered dim so the active month visually dominates.
/// - **Month picker pill + nav chevrons** docked at the bottom of the calendar.
///
/// Tapping a day toggles its completion (toggle habits) or flips between 0 and `dailyTarget`
/// (counter habits — calendar editing is a coarse two-state action by design).
struct CalendarView: View {
    let habit: Habit
    let viewModel: HabitListViewModel

    @Environment(\.modelContext) private var modelContext

    /// The month currently displayed in the grid. Driven by the bottom prev/next chevrons.
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current

    /// Mon-first weekday header order. Index aligns with the grid columns below.
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 14) {
            dayOfWeekRow
            calendarGrid
            bottomBar
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Day-of-week Header

    private var dayOfWeekRow: some View {
        HStack(spacing: 0) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Grid

    /// 6-row × 7-col fixed grid. Showing leading/trailing days from adjacent months keeps the
    /// row count constant, which prevents the bottom bar from jumping when paging months.
    private var calendarGrid: some View {
        let days = calendarDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(days, id: \.self) { date in
                dayCell(for: date)
            }
        }
    }

    /// Single day cell. Composition (back-to-front):
    /// 1. Background pill — dark green when completed.
    /// 2. Today outline — white circle stroke when the date is today.
    /// 3. Number — primary or dim depending on whether the date is in the displayed month.
    /// 4. Completion dot — light green pip below the number when completed.
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isInDisplayedMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date())
        let isBeforeCreation = date < calendar.startOfDay(for: habit.createdAt)
        let isCompleted = habit.isCompleted(for: date)

        Button {
            handleDayTap(date: date)
        } label: {
            ZStack {
                // [Interview] Background pill. Stays slightly inset from the cell bounds so the
                // grid feels airy rather than packed wall-to-wall with green when streaks happen.
                if isCompleted {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gridEmpty)
                        .padding(2)
                }

                // Today indicator — drawn over the pill so it remains visible if today is done.
                if isToday {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 1.5)
                        .padding(6)
                }

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 16, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.6))

                    // Completion dot — light green pip. Always reserve the space so vertical
                    // centering of the number doesn't shift between completed / not.
                    Circle()
                        .fill(isCompleted ? Color.gridFilled : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(isFuture || isBeforeCreation)
    }

    // MARK: - Bottom Bar

    /// "Apr 2026" pill on the left, prev/next chevrons on the right.
    /// Mirrors the layout in the design reference.
    private var bottomBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                Text(monthYearString)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 8) {
                navButton(systemName: "chevron.left") { moveMonth(by: -1) }
                navButton(systemName: "chevron.right") { moveMonth(by: 1) }
                    // Don't allow navigating past the current month — there's no future data.
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.4 : 1.0)
            }
        }
        .padding(.top, 4)
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleDayTap(date: Date) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if habit.completionMode == .toggle {
            viewModel.toggleCompletion(for: habit, on: date, context: modelContext)
        } else {
            // Counter mode: calendar editing is a coarse 0 ↔ target toggle. Fine-grained count
            // editing happens via the home card's increment/decrement controls.
            let current = habit.completionCount(for: date)
            let newCount = current > 0 ? 0 : habit.dailyTarget
            viewModel.setCompletion(for: habit, on: date, count: newCount, context: modelContext)
        }
    }

    // MARK: - Helpers

    /// Build a fixed 6×7 = 42 cell window centered on `displayedMonth`. Includes leading days
    /// from the previous month and trailing days from the next month so every grid is the same
    /// height regardless of where the 1st falls.
    private func calendarDays() -> [Date] {
        guard
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // [Interview] We want Monday as column 0. `.weekday` returns 1=Sun … 7=Sat, so the
        // Monday-first index is `(weekday + 5) % 7`: Sun→6, Mon→0, Tue→1, …, Sat→5.
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingDays = (weekday + 5) % 7

        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: firstOfMonth) else {
            return []
        }

        var dates: [Date] = []
        var cursor = gridStart
        for _ in 0..<42 {
            dates.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return dates
    }

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }
}
