import Foundation
import SwiftData

// Frequency options for a habit — daily means every day, weekly means once per week
enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
}

// How the user marks a habit as done — toggle is yes/no, counter lets them track a number
enum CompletionMode: String, Codable, CaseIterable {
    case toggle = "Toggle"
    case counter = "Counter"
}

// The main Habit model — stored in SwiftData
// Each habit has a name, emoji, frequency, completion mode, and a list of completions
@Model
final class Habit {
    var id: UUID
    var name: String
    var emoji: String
    var frequency: HabitFrequency
    var completionMode: CompletionMode
    var dailyTarget: Int
    var createdAt: Date
    var sortOrder: Int

    // SwiftData relationship — when a habit is deleted, all its completions are too
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]

    init(
        name: String,
        emoji: String = "⭐️",
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

    /// Get the completion record for a specific date (normalized to start of day)
    func completion(for date: Date) -> HabitCompletion? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return completions.first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    /// Check if the habit is completed for a given date
    /// For toggle mode: any completion counts
    /// For counter mode: count must meet or exceed dailyTarget
    func isCompleted(for date: Date) -> Bool {
        guard let completion = completion(for: date) else { return false }
        if completionMode == .toggle {
            return completion.count > 0
        } else {
            return completion.count >= dailyTarget
        }
    }

    /// Get the completion count for a specific date (0 if no record)
    func completionCount(for date: Date) -> Int {
        completion(for: date)?.count ?? 0
    }

    // MARK: - Streak Calculation

    /// Calculate the current streak — consecutive days/weeks the habit was completed
    /// Walks backwards from today, checking each day
    func currentStreak(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: referenceDate)

        // If today isn't completed, start checking from yesterday
        // This way a streak isn't broken just because you haven't done it yet today
        if !isCompleted(for: checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // Walk backwards day by day, counting consecutive completed days
        while isCompleted(for: checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay

            // Safety limit to prevent infinite loops
            if streak > 3650 { break }
        }

        return streak
    }
}
