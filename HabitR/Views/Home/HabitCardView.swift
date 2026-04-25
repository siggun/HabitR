import SwiftUI

/// A single habit tile rendered in the home screen's 2-column grid.
///
/// Composition:
/// - Header row: completion button (morphs between check and emoji), title, month label, and
///   optional counter progress (for `.counter` habits).
/// - Preview grid: 6-week `MiniGridView` visualizing recent completion history.
///
/// ## Interaction model
/// The card exposes three closures — `onToggle`, `onIncrement`, `onDecrement` — to keep the view
/// purely presentational. All state mutation lives in the parent (`TodayView`) so this view can
/// be previewed and tested without a `ModelContext`. `handleCompletionTap()` picks the right
/// closure based on the habit's `completionMode`.
///
/// ## Styling caveat
/// The background is `Color(.systemGray6).opacity(0.5)` — visually close to the app's near-black
/// dark-mode background. This is the same tone used for "missed day" cells in `MiniGridView`,
/// which is why those cells appear to disappear on dark mode. See `MiniGridView`'s class doc.
struct HabitCardView: View {
    let habit: Habit

    /// Tap handler for toggle-mode habits. Invoked from `handleCompletionTap()`.
    let onToggle: () -> Void

    /// Tap handler for counter-mode habits (adds 1 to today's count).
    let onIncrement: () -> Void

    /// Declared on the interface for symmetry — not currently wired to the big button, but used
    /// by contextual affordances in the detail/edit paths. Kept here so the card surface matches.
    let onDecrement: () -> Void

    /// Drives the tap-scale spring animation on the completion button.
    @State private var isAnimating = false

    /// Whether the habit is done *today* per its completion-mode rules. Cached derivations like
    /// these run once per body invocation — SwiftUI handles the memoization for us via `body`
    /// recomputation on `@Query` changes.
    private var isCompletedToday: Bool {
        habit.isCompleted(for: Date())
    }

    /// Today's raw count. Used to render the "3/8" progress label for counter habits.
    private var todayCount: Int {
        habit.completionCount(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader
            MiniGridView(habit: habit)
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // Hairline stroke so the card remains visible against backgrounds of similar tone.
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // MARK: - Card Header

    /// Top row: completion button + text stack. Laid out as an HStack with a trailing `Spacer()`
    /// so the text hugs the button on the left and the card size is driven by the grid below.
    private var cardHeader: some View {
        HStack(spacing: 8) {
            completionButton

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(monthYearLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // [Interview] Counter-mode-only affordance. For toggle habits we skip this row
                // entirely to keep the card compact. `.monospacedDigit()` prevents numerals from
                // changing width as the count increments — otherwise the label would "jitter".
                if habit.completionMode == .counter {
                    Text("\(todayCount)/\(habit.dailyTarget)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompletedToday ? Color.accentColor : .secondary)
                        .monospacedDigit()
                }
            }

            Spacer()
        }
    }

    // MARK: - Completion Button

    /// Morphs between "unchecked" and "completed" states. When completed, it shows the habit's
    /// SF Symbol inside a tinted circle — a small reward signal reinforcing the positive action.
    private var completionButton: some View {
        Button {
            handleCompletionTap()
        } label: {
            if isCompletedToday {
                Image(systemName: habit.emoji)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        // [Interview] `.plain` strips the default blue tint and hover/press effects so our
        // custom circle is the only visual. Without this the button reads as a system link.
        .buttonStyle(.plain)
        .scaleEffect(isAnimating ? 1.2 : 1.0)
    }

    // MARK: - Actions

    /// Combined feedback + routing: play haptic, run the spring animation, and fire the right
    /// closure for the habit's completion mode.
    private func handleCompletionTap() {
        // [Interview] Haptic feedback is generated on the main thread synchronously. For heavy
        // taps this is fine; for rapid-fire increments consider pre-preparing the generator.
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        // [Interview] Manually reset the animated flag after the spring would have settled.
        // Cleaner alternative: attach an `.onAnimationCompleted` modifier — not used here to
        // avoid pulling in a custom modifier for one call site.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }

        if habit.completionMode == .toggle {
            onToggle()
        } else {
            onIncrement()
        }
    }

    // MARK: - Helpers

    /// "Apr 2026"-style label. Re-created per body invocation; acceptable given how rarely this
    /// view re-renders (only on data change) and how cheap `DateFormatter` is to instantiate.
    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }
}
