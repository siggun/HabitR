import Foundation
import SwiftData

/// Cadence on which a habit is expected to be performed.
///
/// Currently drives display/labeling only — streak math in `currentStreak(from:)` walks **daily**
/// regardless of frequency. A future `.weekly` streak implementation should step by
/// `.weekOfYear` and evaluate "any completion within the week" rather than per-day.
enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
}

/// Interaction model for marking a habit complete.
///
/// - `.toggle`:  binary done / not-done. Tapping the check button flips the state.
/// - `.counter`: numeric tracker (e.g. "8 glasses"). Completion is reached when the day's
///               count meets or exceeds `Habit.dailyTarget`.
enum CompletionMode: String, Codable, CaseIterable {
    case toggle = "Toggle"
    case counter = "Counter"
}

/// Root SwiftData model representing a user-tracked habit.
///
/// A `Habit` owns a collection of `HabitCompletion` records — one per completed day. Read paths
/// (streaks, contribution grid, "is today done?") derive state by scanning this collection rather
/// than storing denormalized counters, which keeps the write path trivial and eliminates an entire
/// class of consistency bugs (e.g., a streak counter drifting out of sync with actual completions).
///
/// ## Persistence
/// - `@Model` opts the class into SwiftData — Apple's declarative ORM introduced in iOS 17.
/// - The cascade delete rule on `completions` guarantees orphan-free removal when a habit is
///   deleted; the user never ends up with `HabitCompletion` rows pointing at a missing parent.
///
/// ## Threading
/// - All reads/writes occur on the main actor via SwiftUI view models. SwiftData objects are
///   **not** safe to mutate from background contexts without a dedicated `ModelContext`.
@Model
final class Habit {
    var id: UUID
    var name: String

    /// SF Symbol name (e.g. "star.fill") — rendered via `Image(systemName:)` in the UI.
    /// Stored as a `String` rather than a symbol enum so new symbols don't require a migration.
    var emoji: String

    var frequency: HabitFrequency
    var completionMode: CompletionMode

    /// Target value for `.counter` habits. Ignored for `.toggle`. Kept on the habit (not the
    /// completion) so historical completions automatically reflect a target change.
    var dailyTarget: Int

    /// Wall-clock time at which the habit was created. Used by the contribution grid to render
    /// pre-creation days differently (they aren't "misses" — the habit didn't exist yet).
    var createdAt: Date

    /// Persisted ordering for the home grid. Higher-level code is free to renumber these; the
    /// field exists so SwiftData's `@Query(sort:)` can produce a stable order.
    var sortOrder: Int

    /// One-to-many to `HabitCompletion`.
    ///
    /// `deleteRule: .cascade` — deleting the habit deletes every associated completion row.
    /// Without this, deletions would violate the inverse relationship and SwiftData would log
    /// consistency warnings at runtime.
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]

    init(
        name: String,
        emoji: String = "star.fill",
        frequency: HabitFrequency = .daily,
        completionMode: CompletionMode = .toggle,
        dailyTarget: Int = 1,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.frequency = frequency
        self.completionMode = completionMode
        self.dailyTarget = dailyTarget
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.completions = []
    }

    // MARK: - Completion Helpers

    /// Returns the completion record for the given calendar day, if one exists.
    ///
    /// - Parameter date: Any timestamp within the target day — it is normalized internally.
    /// - Complexity: O(n) where n = `completions.count`. The collection is small (≤ ~day-count),
    ///   so a linear scan outperforms maintaining a separate index. If future usage demands,
    ///   swap this for a `[Date: HabitCompletion]` cache invalidated on writes.
    func completion(for date: Date) -> HabitCompletion? {
        // [Interview] We normalize both sides before comparing: `startOfDay` on the input, and
        // `isDate(_:inSameDayAs:)` on the record's date. The latter is DST-safe — naive ==
        // comparison can fail on spring-forward days where "start of day" shifts by an hour.
        let startOfDay = Calendar.current.startOfDay(for: date)
        return completions.first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Whether the user has satisfied the completion criteria for the given day.
    ///
    /// Toggle habits: any record with `count > 0` counts as complete.
    /// Counter habits: the day's count must meet or exceed `dailyTarget` (overshoot is allowed).
    func isCompleted(for date: Date) -> Bool {
        guard let completion = completion(for: date) else { return false }
        if completionMode == .toggle {
            return completion.count > 0
        } else {
            return completion.count >= dailyTarget
        }
    }

    /// Raw completion count for a day (0 when no record exists). Used by the contribution grid
    /// to distinguish "logged but below target" from "not logged at all".
    func completionCount(for date: Date) -> Int {
        completion(for: date)?.count ?? 0
    }

    // MARK: - Streak Calculation

    /// Current consecutive-day streak ending at (or just before) `referenceDate`.
    ///
    /// Algorithm:
    ///   1. Start at `referenceDate`. If today isn't done yet, don't treat that as a break —
    ///      start walking from yesterday so the user isn't punished for checking the app before
    ///      they've completed today's habits.
    ///   2. Walk backwards one day at a time, incrementing while `isCompleted(for:)` is true.
    ///   3. Stop on the first gap, or on the 3650-day safety cap (~10 years — guards against
    ///      runaway loops if the Calendar arithmetic ever returned `nil` unexpectedly).
    ///
    /// - Complexity: O(streakLength × n) in the worst case, where n = `completions.count`, because
    ///   each `isCompleted(for:)` does a linear scan. Acceptable given the small collection size.
    /// - Parameter referenceDate: Typically "now"; overridable for testing and for the detail view.
    func currentStreak(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: referenceDate)

        // [Interview] Grace period for "today not done yet": we only skip *today* when it's
        // incomplete. If today IS done, we count it, then keep walking backwards from today.
        if !isCompleted(for: checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // [Interview] Walk backwards until we hit an incomplete day. `.day` arithmetic via
        // Calendar is DST-aware, so this naturally handles a 23- or 25-hour day.
        while isCompleted(for: checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay

            // Defensive upper bound. A well-formed Calendar should never trigger this, but the
            // cost of an unbounded loop on the main actor is catastrophic (UI freeze), so we cap.
            if streak > 3650 { break }
        }

        return streak
    }
}
