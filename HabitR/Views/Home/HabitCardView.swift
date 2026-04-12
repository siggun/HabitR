import SwiftUI

// A single habit card for the home screen grid
// Shows a checkmark/emoji toggle, habit name, month label, and mini contribution grid
struct HabitCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @State private var isAnimating = false

    private var isCompletedToday: Bool {
        habit.isCompleted(for: Date())
    }

    private var todayCount: Int {
        habit.completionCount(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: checkmark/emoji + name + month
            cardHeader

            // Mini contribution grid
            MiniGridView(habit: habit)
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack(spacing: 8) {
            // Completion button — checkmark when incomplete, emoji when done
            completionButton

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // Month/year label
                Text(monthYearLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Counter mode: show count/target
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

    private var completionButton: some View {
        Button {
            handleCompletionTap()
        } label: {
            if isCompletedToday {
                // Completed — show habit icon in a colored circle
                Image(systemName: habit.emoji)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
            } else {
                // Not completed — show checkmark icon
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(.systemGray3))
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isAnimating ? 1.2 : 1.0)
    }

    // MARK: - Actions

    private func handleCompletionTap() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Scale animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }

        // Call the right action based on completion mode
        if habit.completionMode == .toggle {
            onToggle()
        } else {
            onIncrement()
        }
    }

    // MARK: - Helpers

    /// Format the current month and year like "Apr 2026"
    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }
}
