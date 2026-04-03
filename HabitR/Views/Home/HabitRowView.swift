import SwiftUI

// A single row in the habit list showing the habit's emoji, name, streak, and completion control
// Supports two modes: toggle (tap to check/uncheck) and counter (tap to increment with long-press to decrement)
struct HabitRowView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    // Track animation state for the check-off bounce effect
    @State private var isAnimating = false

    private var isCompletedToday: Bool {
        habit.isCompleted(for: Date())
    }

    private var todayCount: Int {
        habit.completionCount(for: Date())
    }

    private var streak: Int {
        habit.currentStreak()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Emoji icon
            Text(habit.emoji)
                .font(.title2)

            // Habit name and streak
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body)
                    .fontWeight(.medium)

                if streak > 0 {
                    Label("\(streak) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Completion control — different for toggle vs counter mode
            if habit.completionMode == .toggle {
                toggleButton
            } else {
                counterControl
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Toggle Mode

    private var toggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = true
            }
            // Haptic feedback — UIImpactFeedbackGenerator creates a physical tap sensation
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onToggle()

            // Reset animation after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        } label: {
            Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(isCompletedToday ? Color.accentColor : .gray)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Counter Mode

    private var counterControl: some View {
        HStack(spacing: 8) {
            // Decrement button (only shows when count > 0)
            if todayCount > 0 {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onDecrement()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }

            // Count display — shows current/target
            Text("\(todayCount)/\(habit.dailyTarget)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isCompletedToday ? Color.accentColor : .primary)
                .monospacedDigit()

            // Increment button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isAnimating = true
                }
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onIncrement()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            } label: {
                Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(isCompletedToday ? Color.accentColor : Color.accentColor.opacity(0.7))
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }
}
