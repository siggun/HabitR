import Foundation
import SwiftData

// A single completion record for a habit on a specific day
// For toggle habits, count is always 0 or 1
// For counter habits, count tracks the number (e.g., 5 glasses of water)
@Model
final class HabitCompletion {
    var id: UUID
    var date: Date
    var count: Int
    var habit: Habit?

    init(date: Date, count: Int = 1, habit: Habit? = nil) {
        self.id = UUID()
        // Normalize to start of day to avoid time-of-day comparison issues
        self.date = Calendar.current.startOfDay(for: date)
        self.count = count
        self.habit = habit
    }
}
