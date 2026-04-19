import SwiftUI

// MARK: - Shared Grid Palette

/// GitHub-style fixed green palette used by every contribution grid in the app.
///
/// Defined as a `Color` extension (rather than asset-catalog colors) so we don't have to touch
/// the Xcode project to pick up new files. Tones are tuned for the app's #1A1B1D dark
/// background — they remain legible without being so bright they distract from accent UI.
extension Color {
    /// Muted dark-green tone. Two uses:
    /// - Fill for empty contribution-grid cells (missed / future / pre-creation days).
    /// - Background pill for completed days in the calendar (the date number reads on top).
    static let gridMuted = Color(red: 0.10, green: 0.20, blue: 0.13)

    /// Bright green accent tone. Two uses:
    /// - Fill for completed contribution-grid cells.
    /// - Small completion dot below calendar dates and the streak-flame icon.
    static let gridAccent = Color(red: 0.21, green: 0.83, blue: 0.45)
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
/// Single tone for empty (`Color.gridMuted`), single tone for filled (`Color.gridAccent`). No
/// distinction between missed / future / pre-creation — see `Color.gridMuted` doc.
///
/// ## Scroll behavior
/// `.defaultScrollAnchor(.trailing)` (iOS 17+) pins the initial scroll position to the trailing
/// edge so "today" sits flush with the right side of the card on first open. This is declarative
/// — no `ScrollViewReader` / `scrollTo` / `onAppear` plumbing — which avoids the timing race
/// where `onAppear` fires before layout is final and leaves a trailing gap.
struct GridView: View {
    let habit: Habit

    /// 52 weeks ≈ 12 months. Matches the screenshot's reachable scroll range.
    private let weeksToShow = 52

    /// Cell edge length. Chosen to feel comfortable when ~7 weeks fit on-screen at once.
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    /// Width reserved for the day-of-week label gutter on the left side.
    private let dayLabelWidth: CGFloat = 28

    var body: some View {
        // [Interview] `safeAreaInset` is the SwiftUI primitive purpose-built for this exact
        // pattern: a fixed sidebar pinned alongside a ScrollView. It reserves space at the
        // ScrollView's leading edge for the inset content (our day-label gutter) and feeds the
        // remaining width to the scrollable area — no GeometryReader, no HStack width-distribution
        // heuristics, no .frame(maxWidth) tricks.
        //
        // Why earlier attempts (HStack + maxWidth, then GeometryReader) failed: a horizontal
        // ScrollView with `.defaultScrollAnchor(.trailing)` confuses the HStack's flex-shrink
        // path because the ScrollView reports its 881pt content width as an intrinsic size hint.
        // safeAreaInset bypasses that entirely by attaching the gutter via the safe-area system,
        // which is independent of HStack/VStack width distribution.
        //
        // The `Color.clear` spacer in `dayLabelsColumn` is sized to (monthHeaderHeight +
        // headerToGridSpacing + topPadding) so the Tue/Thu/Sat labels align with the matching
        // grid rows below the month header — see `dayLabelsColumn` for the exact arithmetic.
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                monthHeaderRow
                gridRows
            }
            .padding(.vertical, 4)
        }
        .defaultScrollAnchor(.trailing)
        .safeAreaInset(edge: .leading, alignment: .top, spacing: 6) {
            dayLabelsColumn
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Labels

    /// Left gutter showing Tue / Thu / Sat labels at rows 1, 3, 5. Other rows render an
    /// empty placeholder so vertical alignment with the grid stays exact.
    ///
    /// The leading `Color.clear` spacer matches the vertical offset of the grid's first row
    /// inside the ScrollView so the labels line up:
    /// - 4pt: matches `.padding(.vertical, 4)` on the inner VStack
    /// - 16pt: monthHeaderHeight
    /// - 4pt: VStack(spacing: 4) gap between header and grid rows
    /// = 24pt total. Keep this in lockstep with `body`'s ScrollView content layout.
    private var dayLabelsColumn: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            Color.clear.frame(height: monthHeaderHeight + 8)

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
    /// painted into it. `.fixedSize()` lets the text render at its natural width without
    /// truncation, and the trailing `.frame(width: cellSize)` locks each slot's **layout**
    /// contribution back to the grid's column width — so a wide month name visually spills into
    /// the empty neighbor slot without pushing the header row wider than the grid rows below.
    /// (If header width exceeded grid width, `.defaultScrollAnchor(.trailing)` would align on the
    /// header's trailing edge and leave a trailing gap on the grid.)
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
                .frame(width: cellSize, height: monthHeaderHeight, alignment: .leading)
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
    private var gridRows: some View {
        let weeks = gridWeeks()
        return VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { dayIndex in
                HStack(spacing: cellSpacing) {
                    ForEach(weeks.indices, id: \.self) { weekIdx in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cellColor(for: weeks[weekIdx][dayIndex]))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    /// Two-state cell coloring — see file-level palette doc.
    private func cellColor(for date: Date) -> Color {
        habit.completionCount(for: date) > 0 ? .gridAccent : .gridMuted
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
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                    assertionFailure("Calendar failed to advance date")
                    return weeks
                }
                cursor = next
            }
            weeks.append(week)
        }
        return weeks
    }
}
