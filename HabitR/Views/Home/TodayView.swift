import SwiftUI
import SwiftData

// The main screen — shows today's habits as a list with check-off controls
// This is the first screen users see after onboarding
struct TodayView: View {
    // @Query automatically fetches all Habit objects from SwiftData
    // and updates the view when data changes
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = HabitListViewModel()
    @ObservedObject private var storeKit = StoreKitService.shared

    @State private var showingAddHabit = false
    @State private var showingPaywall = false
    @State private var showingSettings = false
    @State private var selectedHabit: Habit?

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    emptyStateView
                } else {
                    habitListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                // Separate ToolbarItem so SwiftUI renders the text reliably
                // (mixing Text + Button in a single ToolbarItem HStack can clip the Text)
                ToolbarItem(placement: .topBarLeading) {
                    Text("HabitR")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { handleAddHabit() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddEditHabitView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedHabit) { habit in
                NavigationStack {
                    HabitDetailView(habit: habit)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Habits Yet", systemImage: "checkmark.circle.badge.plus")
        } description: {
            Text("Tap + to create your first habit and start building streaks.")
        }
    }

    private var habitListView: some View {
        List {
            ForEach(habits) { habit in
                HabitRowView(
                    habit: habit,
                    onToggle: { toggleHabit(habit) },
                    onIncrement: { incrementHabit(habit) },
                    onDecrement: { decrementHabit(habit) }
                )
                .contentShape(Rectangle())
                .onTapGesture { selectedHabit = habit }
            }
            .onDelete(perform: deleteHabits)
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func handleAddHabit() {
        if viewModel.canAddHabit(currentCount: habits.count, isSubscribed: storeKit.isSubscribed) {
            showingAddHabit = true
        } else {
            showingPaywall = true
        }
    }

    private func toggleHabit(_ habit: Habit) {
        viewModel.toggleCompletion(for: habit, on: Date(), context: modelContext)
    }

    private func incrementHabit(_ habit: Habit) {
        viewModel.incrementCounter(for: habit, on: Date(), context: modelContext)
    }

    private func decrementHabit(_ habit: Habit) {
        viewModel.decrementCounter(for: habit, on: Date(), context: modelContext)
    }

    private func deleteHabits(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteHabit(habits[index], context: modelContext)
        }
    }
}
