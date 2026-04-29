import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Root of the authenticated app surface — the home screen that users land on after onboarding.
///
/// Responsibilities:
/// - Fetch all habits from SwiftData via `@Query` and render them in a 2-column grid of cards.
/// - Coordinate the three modal sheets: Add Habit, Paywall, and Settings.
/// - Gate new-habit creation through the free-tier check before presenting the add sheet.
/// - Push to `HabitDetailView` when a card is tapped.
///
/// ## Data flow
/// `@Query` is SwiftData's live-fetching property wrapper. It re-fires the view's `body` whenever
/// the underlying store changes — this is why we never have to call `setNeedsLayout` or manually
/// refresh after `HabitListViewModel` mutates a record.
///
/// `HabitListViewModel` is stateless, so `@StateObject` is a slight overkill here (`@State` with
/// a plain struct would work), but using `@StateObject` keeps the door open for adding
/// `@Published` state later without a wider refactor.
struct TodayView: View {
    /// Sorted by `sortOrder` so the UI matches user-reorderings once those are introduced.
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    /// Context handed down by the app's `.modelContainer` modifier. Passed into the VM for
    /// each mutating call.
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = HabitListViewModel()
    @ObservedObject private var storeKit = StoreKitService.shared

    @State private var showingAddHabit = false
    @State private var showingPaywall = false
    @State private var showingSettings = false

    /// Non-nil when the user has tapped a card. Binding to `.sheet(item:)` ensures the sheet
    /// is dismissed (and this set back to `nil`) automatically when the user swipes down.
    @State private var selectedHabit: Habit?
    @State private var draggingHabit: Habit?

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
            // [Interview] Matching the toolbar background to the app background prevents the
            // default translucent material from muddying our custom dark grey (#1A1B1D).
            .toolbarBackground(Color("AppBackground"), for: .navigationBar)
            .background(Color("AppBackground"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                // [Interview] Two-tone branded title: "Habit" in default foreground, "R" in the
                // accent color. Using an HStack with `spacing: 0` so the two Texts read as one
                // word visually while remaining separately styleable.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 0) {
                        Text("Habit")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("R")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { handleAddHabit() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) { AddEditHabitView() }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $selectedHabit) { habit in
                // [Interview] No NavigationStack — the redesigned detail sheet renders its own
                // header (icon + title + close X) and doesn't need a system nav bar.
                HabitDetailView(habit: habit)
            }
        }
    }

    // MARK: - Subviews

    /// First-run / empty-state placeholder. `ContentUnavailableView` is Apple's iOS 17 API for
    /// standardized empty states — we prefer it over a hand-rolled VStack for consistency with
    /// other system apps.
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Habits Yet", systemImage: "checkmark.circle.badge.plus")
        } description: {
            Text("Tap + to create your first habit and start building streaks.")
        }
    }

    /// The card grid. `LazyVGrid` renders rows on demand as the user scrolls, which keeps
    /// memory flat for users with many habits (relevant for subscribers only — free tier caps
    /// at 3, but we don't want to refactor this once someone subscribes).
    private var habitListView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(habits) { habit in
                    HabitCardView(
                        habit: habit,
                        onToggle: { toggleHabit(habit) },
                        onIncrement: { incrementHabit(habit) },
                        onDecrement: { decrementHabit(habit) }
                    )
                    // Tap the card body to drill in; the completion button intercepts its own
                    // taps via its Button, so they don't bubble up to this gesture.
                    .onTapGesture { selectedHabit = habit }
                    .opacity(draggingHabit?.id == habit.id ? 0.5 : 1.0)
                    .onDrag {
                        draggingHabit = habit
                        return NSItemProvider(object: habit.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: HabitDropDelegate(
                        targetHabit: habit,
                        allHabits: habits,
                        draggingHabit: $draggingHabit
                    ))
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteHabit(habit, context: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    /// Decide whether "+" should show the create sheet or redirect to the paywall.
    ///
    /// Centralizing this in one method (rather than inlining the ternary) makes the monetization
    /// gate trivially testable and ensures both the button and any future shortcuts (Siri, etc.)
    /// hit the same check.
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
}

// MARK: - Drag-to-Reorder

private struct HabitDropDelegate: DropDelegate {
    let targetHabit: Habit
    let allHabits: [Habit]
    @Binding var draggingHabit: Habit?

    func performDrop(info: DropInfo) -> Bool {
        withAnimation { draggingHabit = nil }
        return true
    }

    func dropExited(info: DropInfo) {
        withAnimation { draggingHabit = nil }
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingHabit,
              dragging.id != targetHabit.id,
              let fromIndex = allHabits.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = allHabits.firstIndex(where: { $0.id == targetHabit.id }),
              fromIndex != toIndex
        else { return }

        var reordered = Array(allHabits)
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)

        withAnimation {
            for (i, h) in reordered.enumerated() {
                h.sortOrder = i
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
