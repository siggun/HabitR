import Foundation
import os
import SwiftData
import SwiftUI

private let log = Logger(subsystem: "HabitR", category: "HabitListViewModel")

/// View model backing the home screen (`TodayView`) and the detail/calendar edit paths.
///
/// Responsibilities:
/// - Mutating habit completion state (toggle / increment / decrement / explicit set).
/// - Enforcing the free-tier habit cap (`freeHabitLimit`) in concert with `StoreKitService`.
/// - Deleting habits (cascade to completions is handled by SwiftData, not here).
///
/// Design notes:
/// - This VM is **stateless** — it holds no `@Published` properties. The home screen reads its
///   habit list directly via `@Query`, so there is nothing for this VM to republish. Keeping it
///   stateless simplifies testing and avoids double-sourcing data.
/// - `ModelContext` is passed in per call rather than injected at construction time. This keeps
///   the VM decoupled from any particular container and mirrors how SwiftUI hands contexts to
///   views (via `@Environment(\.modelContext)`).
/// - `@MainActor` is correct and intentional: all writes must land on the main thread because
///   SwiftData objects read by SwiftUI views live in the main context.
@MainActor
final class HabitListViewModel: ObservableObject {
    /// Free-tier ceiling. Creation past this requires an active subscription
    /// (`StoreKitService.isSubscribed == true`). Kept as a `static` so the paywall and the
    /// create-habit screen reference the same source of truth.
    static let freeHabitLimit = 3

    // MARK: - Toggle Mode

    /// Flip the completion state for a toggle-mode habit on `date`.
    ///
    /// Semantics: idempotent with respect to a given day — calling twice returns to the original
    /// state. Used by the big check button on the home card.
    ///
    /// - Note: We mutate both the SwiftData context **and** the in-memory relationship array.
    ///   SwiftData usually syncs the array automatically, but doing both defensively avoids a
    ///   rare iOS 17.0–17.2 issue where the array stays stale until the next fetch.
    func toggleCompletion(for habit: Habit, on date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        if let existing = habit.completion(for: startOfDay) {
            // [Interview] Already marked done → treat the tap as an "undo". Delete the row and
            // also scrub the in-memory array so the UI reflects the change before the next fetch.
            context.delete(existing)
            habit.completions.removeAll { $0.id == existing.id }
        } else {
            // [Interview] Not yet done → create a fresh completion pinned to startOfDay.
            // `count: 1` is the canonical "done" marker for toggle habits.
            let completion = HabitCompletion(date: startOfDay, count: 1, habit: habit)
            context.insert(completion)
            habit.completions.append(completion)
        }
        saveContext(context)
    }

    // MARK: - Counter Mode

    /// Add one to the day's counter, creating the record on first increment.
    /// Overshooting `dailyTarget` is intentionally permitted — the UI surfaces this as "exceeded".
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

    /// Subtract one from the day's counter. Deletes the row when the count would hit zero so the
    /// "no record" invariant for empty days is preserved (see `HabitCompletion`'s doc comment).
    func decrementCounter(for habit: Habit, on date: Date, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        guard let existing = habit.completion(for: startOfDay) else { return }

        if existing.count <= 1 {
            // [Interview] About to hit 0. Rather than persisting count=0 (which would violate our
            // "zero is not a valid stored value" invariant), we delete the record entirely.
            context.delete(existing)
            habit.completions.removeAll { $0.id == existing.id }
        } else {
            existing.count -= 1
        }
        saveContext(context)
    }

    /// Set a specific completion count — used by the calendar view when the user edits a past day.
    ///
    /// Handles all three transitions in one entry point:
    /// - `count <= 0` → delete any existing record.
    /// - existing row present → mutate in place.
    /// - no row present → insert a new one.
    func setCompletion(for habit: Habit, on date: Date, count: Int, context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: date)

        if count <= 0 {
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

    // MARK: - Tier Enforcement

    /// Gate for the "+" button on the home screen.
    ///
    /// - Returns: `true` when the user may create a new habit — either they are already under the
    ///   free cap, or they hold an active subscription. When this returns `false`, `TodayView`
    ///   shows the paywall instead of the create-habit sheet.
    func canAddHabit(currentCount: Int, isSubscribed: Bool) -> Bool {
        isSubscribed || currentCount < Self.freeHabitLimit
    }

    // MARK: - Deletion

    /// Delete a habit. Associated completions are removed by the cascade rule on
    /// `Habit.completions`, so we don't enumerate them manually.
    func deleteHabit(_ habit: Habit, context: ModelContext) {
        context.delete(habit)
        saveContext(context)
    }

    // MARK: - Private

    /// Persist pending changes in the context.
    ///
    /// Failure handling intentionally logs and swallows — SwiftData save errors in this app are
    /// effectively unrecoverable (disk full, data corruption) and surfacing them in the UI adds
    /// no actionable recourse for the user. Convert to an error-bubbling signature if richer
    /// diagnostics become necessary.
    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            log.error("Failed to save context: \(error.localizedDescription, privacy: .public)")
        }
    }
}
