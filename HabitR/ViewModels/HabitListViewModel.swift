import Foundation
import SwiftData
import SwiftUI

// ViewModel for the TodayView — manages habit completion logic, streak calculations,
// and enforces the 3-habit free limit
@MainActor
final class HabitListViewModel: ObservableObject {
    /// Maximum number of habits allowed on the free tier
    static let freeHabitLimit = 3

    /// Toggle a habit's completion for a given date (toggle mode)
    /// If already completed, removes the completion. If not, adds one.
    func toggleCompletion(for habit: Habit, on date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        if let existing = habit.completion(for: startOfDay) {
            // Already completed — remove it
            context.delete(existing)
            habit.completions.removeAll { $0.id == existing.id }
        } else {
            // Not completed — add a new completion
            let completion = HabitCompletion(date: startOfDay, count: 1, habit: habit)
            context.insert(completion)
            habit.completions.append(completion)
        }
        saveContext(context)
    }

    /// Increment the counter for a counter-mode habit
    /// Creates a new completion if none exists, otherwise increments the count
    func incrementCounter(for habit: Habit, on date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        if let existing = habit.completion(for: startOfDay) {
            existing.count += 1
        } else {
            let completion = HabitCompletion(date: startOfDay, count: 1, habit: habit)
            context.insert(completion)
            habit.completions.append(completion)
        }
        saveContext(context)
    }

    /// Decrement the counter for a counter-mode habit
    /// If count reaches 0, removes the completion record entirely
    func decrementCounter(for habit: Habit, on date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        guard let existing = habit.completion(for: startOfDay) else { return }

        if existing.count <= 1 {
            // Count would reach 0 — remove the completion
            context.delete(existing)
            habit.completions.removeAll { $0.id == existing.id }
        } else {
            existing.count -= 1
        }
        saveContext(context)
    }

    /// Set a specific completion count for a date (used by calendar editing)
    func setCompletion(for habit: Habit, on date: Date, count: Int, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        if count <= 0 {
            // Remove completion
            if let existing = habit.completion(for: startOfDay) {
                context.delete(existing)
                habit.completions.removeAll { $0.id == existing.id }
            }
        } else if let existing = habit.completion(for: startOfDay) {
            existing.count = count
        } else {
            let completion = HabitCompletion(date: startOfDay, count: count, habit: habit)
            context.insert(completion)
            habit.completions.append(completion)
        }
        saveContext(context)
    }

    /// Check if adding a new habit would exceed the free tier limit
    func canAddHabit(currentCount: Int, isSubscribed: Bool) -> Bool {
        isSubscribed || currentCount < Self.freeHabitLimit
    }

    /// Delete a habit and all its completions
    func deleteHabit(_ habit: Habit, context: ModelContext) {
        context.delete(habit)
        saveContext(context)
    }

    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
