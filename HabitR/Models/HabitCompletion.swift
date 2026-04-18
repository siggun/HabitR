import Foundation
import SwiftData

/// A single completion record representing that a habit was performed on a specific calendar day.
///
/// Completion semantics vary by `Habit.completionMode`:
/// - `.toggle` habits use `count` as a boolean flag (`1` = done, absence of record = not done).
/// - `.counter` habits use `count` to track a numeric value (e.g. glasses of water).
///
/// Invariants:
/// - At most **one** `HabitCompletion` exists per `(habit, day)` pair. Enforcement lives in
///   `HabitListViewModel` — it looks up the existing record before inserting a new one.
/// - `date` is always normalized to the start of the local day via `Calendar.startOfDay(for:)`.
///   Storing un-normalized timestamps would break same-day lookups across midnight boundaries.
/// - Lifetime is bound to the parent `Habit` via a cascade delete rule declared on `Habit.completions`.
///
/// Thread-safety: SwiftData `@Model` instances must be mutated on the thread of their owning
/// `ModelContext`. All mutations in this app flow through `@MainActor` view models.
@Model
final class HabitCompletion {
    /// Stable identifier. Not used for equality in SwiftData (SwiftData uses persistent IDs),
    /// but kept as a convenience for diffing collections in SwiftUI.
    var id: UUID

    /// Calendar day this completion represents, normalized to 00:00:00 local time in `init`.
    var date: Date

    /// Numeric completion value. `1` for toggle habits; arbitrary non-negative for counters.
    /// Zero is not a valid persisted state — the VM deletes the record instead of storing `0`.
    var count: Int

    /// Inverse of `Habit.completions`. Optional because SwiftData requires inverse relationships
    /// to be nullable on the "many" side to support orphan handling during deletes.
    var habit: Habit?

    init(date: Date, count: Int = 1, habit: Habit? = nil) {
        self.id = UUID()
        // [Interview] Normalization guard: if a caller passes `Date()` at 23:59, we still want
        // this record to match a lookup for "today" at 00:00 tomorrow morning. startOfDay pins
        // the timestamp to the local midnight boundary using the user's current Calendar.
        self.date = Calendar.current.startOfDay(for: date)
        self.count = count
        self.habit = habit
    }
}
