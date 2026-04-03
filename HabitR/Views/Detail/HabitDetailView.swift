import SwiftUI

// Detail view for a single habit — shows the GitHub-style grid and calendar
// Accessed by tapping a habit in the TodayView list
struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HabitListViewModel()

    @State private var showingEditSheet = false
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with emoji, name, and streak
                headerSection

                // Segmented control for grid vs calendar view
                Picker("View", selection: $selectedTab) {
                    Text("Grid").tag(0)
                    Text("Calendar").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Show selected view
                if selectedTab == 0 {
                    GridView(habit: habit)
                } else {
                    CalendarView(habit: habit, viewModel: viewModel)
                }

                // Stats section
                statsSection
            }
            .padding(.bottom, 20)
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditSheet = true } label: {
                    Text("Edit")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Text("Done")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditHabitView(habitToEdit: habit)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(habit.emoji)
                .font(.system(size: 60))

            Text(habit.name)
                .font(.title2)
                .fontWeight(.bold)

            if habit.currentStreak() > 0 {
                Label("\(habit.currentStreak()) day streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            Text(habit.frequency.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
        .padding(.top, 10)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let totalCompletions = habit.completions.reduce(0) { $0 + $1.count }
        let totalDays = habit.completions.count

        return VStack(spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            HStack(spacing: 20) {
                StatCard(title: "Current Streak", value: "\(habit.currentStreak())", icon: "flame.fill")
                StatCard(title: "Total Days", value: "\(totalDays)", icon: "calendar")
                StatCard(title: "Completions", value: "\(totalCompletions)", icon: "checkmark.circle")
            }
            .padding(.horizontal)
        }
    }
}

// A small card showing a single stat — used in the detail view's stats section
struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
