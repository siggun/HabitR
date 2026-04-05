import SwiftUI
import SwiftData

// User-selectable theme override — persisted via @AppStorage
// .system lets the OS decide; .light / .dark force the app's color scheme
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    // Passing nil to .preferredColorScheme() means "follow the system"
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// @main marks this as the app's entry point
// SwiftUI apps use the App protocol instead of AppDelegate
@main
struct HabitRApp: App {
    /// Track whether onboarding has been completed — persisted in UserDefaults via @AppStorage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// User-selected theme — defaults to Dark on first launch per product decision
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.dark.rawValue

    var body: some Scene {
        // Recomputed whenever appThemeRaw changes, which flips the scheme app-wide
        let theme = AppTheme(rawValue: appThemeRaw) ?? .dark

        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    TodayView()
                } else {
                    OnboardingView()
                }
            }
            // Apply the chosen color scheme to the entire view tree
            // nil (for .system) means SwiftUI uses the system's color scheme
            .preferredColorScheme(theme.colorScheme)
        }
        // modelContainer sets up SwiftData for the entire app
        // All views below this can access the database via @Query or @Environment(\.modelContext)
        .modelContainer(for: [Habit.self, HabitCompletion.self])
    }
}
