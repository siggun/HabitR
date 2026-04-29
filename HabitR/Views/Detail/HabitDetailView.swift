import SwiftUI

/// Bottom-sheet detail surface for a single habit.
///
/// Layout (top → bottom):
/// 1. **Header row** — habit icon, name + subtitle, close button.
/// 2. **Yearly contribution grid** (`GridView`) — horizontally scrollable, anchored on today.
/// 3. **Action row** — "No Streak Goal" pill, streak counter, edit + gear buttons.
/// 4. **Divider** — visual break before the calendar.
/// 5. **Month calendar** (`CalendarView`) — Mon-first, with bottom prev/next nav.
///
/// ## Why a sheet instead of a push
/// Presenting as a sheet (rather than navigation push) keeps the home grid visible behind a
/// dimmed/blurred backdrop — the user retains spatial context that they're "looking into" a
/// habit, not navigating away from the home surface. This is also why we don't render a system
/// nav bar here; an explicit close (×) button is enough.
///
/// ## Open items vs. design
/// - "No Description" / "No Streak Goal" are static strings — neither field is on `Habit` yet.
/// - Gear button is a placeholder (no per-habit settings screen exists).
/// Both are clearly marked below so they're easy to wire up later.
struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HabitListViewModel()

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        // [Interview] Compute the streak once per body evaluation. `currentStreak()` walks
        // backwards through completions, so caching avoids re-doing that work for every subview
        // that reads it (currently just the action row, but cheap insurance against future reads).
        let streak = habit.currentStreak()

        return VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    GridView(habit: habit)
                        .padding(.top, 4)
                        .padding(.leading, -19)
                        .padding(.trailing, 0)

                    actionRow(streak: streak)

                    Divider()
                        .background(Color.white.opacity(0.06))

                    CalendarView(habit: habit, viewModel: viewModel)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color("AppBackground"))
        .sheet(isPresented: $showingEditSheet) {
            AddEditHabitView(habitToEdit: habit)
        }
        .alert("Delete Habit", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteHabit(habit, context: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(habit.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: habit.emoji)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                // [Interview] Static placeholder — no description field on Habit yet. Adding one
                // requires a SwiftData schema migration; deferred until product asks for it.
                Text("No Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Action Row

    /// Row beneath the contribution grid: streak-goal pill, streak counter, edit, gear.
    private func actionRow(streak: Int) -> some View {
        HStack(spacing: 10) {
            // [Interview] Static — Habit doesn't track a goal target. When goals ship, swap
            // this string for the user's configured target ("30 day goal", etc.).
            Text("No Streak Goal")
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gridAccent)
                Text("\(streak)")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            Spacer()

            iconButton(systemName: "square.and.pencil", label: "Edit habit") {
                showingEditSheet = true
            }

            // [Interview] Placeholder for future per-habit settings (notifications, archive,
            // delete, etc.). Wired to the same edit sheet for now so the button feels alive.
            iconButton(systemName: "gearshape", label: "Habit settings") {
                showingDeleteConfirmation = true
            }
        }
    }

    private func iconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
