import SwiftUI

// MARK: - Shared Grid Palette

/// GitHub-style fixed green palette used by every contribution grid in the app.
///
/// Defined as a `Color` extension (rather than asset-catalog colors) so we don't have to touch
/// the Xcode project to pick up new files. Tones are tuned for the app's #1A1B1D dark
/// background — they remain legible without being so bright they distract from accent UI.
extension Color {
    /// Empty cell tone — used for missed days, future days, and pre-creation days alike.
    /// Deliberately the only "non-completed" color so empty days render uniformly.
    static let gridEmpty = Color(red: 0.10, green: 0.20, blue: 0.13)

    /// Completed cell tone — bright green for visual reward.
    static let gridFilled = Color(red: 0.21, green: 0.83, blue: 0.45)
}

/// Horizontal-scrolling 12-month contribution grid, GitHub-style.
///
/// Layout (transposed from the home-screen mini grid):
/// - **7 rows** — one per day of week, Monday on top. Labels for Tue / Thu / Sat appear in a
///   left-side gutter (every-other row is a common space-saving pattern).
/// - **52 columns** — one per ISO week, ordered oldest → most recent. The most recent week
///   anchors against the right edge so the user lands on "today" on first open.
/// - **Month headers** float above the column whose Monday begins a new month.
///
/// ## Color policy
/// Single tone for empty (`Color.gridEmpty`), single tone for filled (`Color.gridFilled`). No
/// distinction between missed / future / pre-creation — see `Color.gridEmpty` doc.
///
/// ## Scroll behavior
/// `ScrollViewReader.scrollTo(_:anchor:)` is fired in `.onAppear` to pin the most recent week
/// to the trailing edge. Without this, horizontal ScrollViews default to leading.
struct GridView: View {
    let habit: Habit

    /// 52 weeks ≈ 12 months. Matches the screenshot's reachable scroll range.
    private let weeksToShow = 52

    /// Cell edge length. Chosen to feel comfortable when ~7 weeks fit on-screen at once.
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    /// Width reserved for the day-of-week label gutter on the left side.
    private let dayLabelWidth: CGFloat = 28

    /// Sticky scroll anchor id. Used to scroll the latest week into view on appear.
    private let latestWeekID = "latest-week"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    dayLabelsColumn

                    VStack(alignment: .leading, spacing: 4) {
                        monthHeaderRow
                        gridRows
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                // [Interview] `.trailing` aligns the latest column to the right edge of the
                // scroll viewport — i.e. "today" sits at the far right on first open.
                proxy.scrollTo(latestWeekID, anchor: .trailing)
            }
        }
    }

    // MARK: - Day Labels

    /// Left gutter showing Tue / Thu / Sat labels at rows 1, 3, 5. Other rows render an
    /// empty placeholder so vertical alignment with the grid stays exact.
    private var dayLabelsColumn: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            // Reserve space matching the month header above the grid so day labels
            // line up with their actual day rows, not the header.
            Color.clear.frame(height: monthHeaderHeight)

            ForEach(0..<7, id: \.self) { row in
                Text(dayLabel(forRow: row))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: dayLabelWidth, height: cellSize, alignment: .trailing)
            }
        }
    }

    /// Mon-first label policy — empty for unlabeled rows.
    private func dayLabel(forRow row: Int) -> String {
        switch row {
        case 1: return "Tue"
        case 3: return "Thu"
        case 5: return "Sat"
        default: return ""
        }
    }

    // MARK: - Month Header

    private var monthHeaderHeight: CGFloat { 16 }

    /// Row of month names floating above the grid. We render one slot per week column; the slot
    /// is empty unless that week contains the 1st of a month, in which case the month name is
    /// painted into it. `.fixedSize()` lets the text overflow into adjacent slots so wider names
    /// like "September" don't truncate.
    private var monthHeaderRow: some View {
        let weeks = gridWeeks()
        return HStack(alignment: .bottom, spacing: cellSpacing) {
            ForEach(weeks.indices, id: \.self) { idx in
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: cellSize, height: monthHeaderHeight)
                    if let label = monthLabel(for: weeks[idx], previous: idx > 0 ? weeks[idx - 1] : nil) {
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
            }
        }
    }

    /// Returns the abbreviated month name when this week is the first one in a new month
    /// (i.e. its month differs from the previous week's). Otherwise nil.
    private func monthLabel(for week: [Date], previous: [Date]?) -> String? {
        let calendar = Calendar.current
        guard let firstDay = week.first else { return nil }
        let month = calendar.component(.month, from: firstDay)
        if let prev = previous?.first {
            let prevMonth = calendar.component(.month, from: prev)
            guard month != prevMonth else { return nil }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: firstDay)
    }

    // MARK: - Grid Body

    /// Seven rows (Mon→Sun), each row spanning `weeksToShow` week columns.
    /// We tag the top-right cell with `latestWeekID` so the ScrollViewReader can find it.
    private var gridRows: some View {
        let weeks = gridWeeks()
        return VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { dayIndex in
                HStack(spacing: cellSpacing) {
                    ForEach(weeks.indices, id: \.self) { weekIdx in
                        cell(
                            for: weeks[weekIdx][dayIndex],
                            isAnchor: weekIdx == weeks.count - 1 && dayIndex == 0
                        )
                    }
                }
            }
        }
    }

    /// Single grid cell. The trailing-most cell is tagged with the scroll-anchor id; tagging
    /// every cell would be wasteful and could confuse ScrollViewReader's match.
    @ViewBuilder
    private func cell(for date: Date, isAnchor: Bool) -> some View {
        let rect = RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(for: date))
            .frame(width: cellSize, height: cellSize)
        if isAnchor {
            rect.id(latestWeekID)
        } else {
            rect
        }
    }

    /// Two-state cell coloring — see file-level palette doc.
    private func cellColor(for date: Date) -> Color {
        habit.completionCount(for: date) > 0 ? .gridFilled : .gridEmpty
    }

    // MARK: - Grid Data

    /// Builds a `[week][dayOfWeek]` matrix where day-of-week index 0 = Monday.
    ///
    /// Algorithm:
    /// 1. Find the Monday of the current week (anchor on today).
    /// 2. Step back `weeksToShow - 1` weeks to find the grid's first Monday.
    /// 3. Generate 52 weeks of 7 days each, walking forward.
    private func gridWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // [Interview] `.weekday` returns 1=Sun … 7=Sat. To get Monday-of-this-week, we compute
        // an offset that maps Sun→-6, Mon→0, Tue→-1, …, Sat→-5. The expression below produces
        // exactly that, handling the Sunday wraparound case correctly.
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        guard let startOfThisWeek = calendar.date(byAdding: .day, value: mondayOffset, to: today),
              let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: startOfThisWeek)
        else { return [] }

        var weeks: [[Date]] = []
        var cursor = gridStart

        for _ in 0..<weeksToShow {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(cursor)
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
            weeks.append(week)
        }
        return weeks
    }
}
