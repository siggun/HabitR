import SwiftUI
import SwiftData

// @main marks this as the app's entry point
// SwiftUI apps use the App protocol instead of AppDelegate
@main
struct HabitRApp: App {
    /// Track whether onboarding has been completed — persisted in UserDefaults via @AppStorage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                TodayView()
            } else {
                OnboardingView()
            }
        }
        // modelContainer sets up SwiftData for the entire app
        // All views below this can access the database via @Query or @Environment(\.modelContext)
        .modelContainer(for: [Habit.self, HabitCompletion.self])
    }
}
