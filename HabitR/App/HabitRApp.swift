import SwiftUI
import SwiftData

/// User-selectable theme override. Persisted via `@AppStorage("appTheme")`.
///
/// `.system` defers to the OS. `.light` / `.dark` force the color scheme regardless of the
/// system setting — passed through to SwiftUI's `.preferredColorScheme(_:)` modifier.
///
/// Stored as its raw string value rather than an `Int` or `Bool` so the persisted format stays
/// human-readable (handy during debugging via `defaults read`) and so adding new cases later
/// (`.oled`, `.highContrast`, …) doesn't require a migration.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    /// User-facing label for the Settings picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Bridge to SwiftUI's `ColorScheme`. Returning `nil` for `.system` is how you tell
    /// `.preferredColorScheme(_:)` "use whatever the OS decides" — any non-nil value forces.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Application entry point.
///
/// SwiftUI apps use the `App` protocol + `@main` annotation rather than the classic UIKit
/// `AppDelegate` / `SceneDelegate` pair. The body returns a `Scene` tree, and the first (and
/// only) `WindowGroup` becomes the app's main window.
///
/// ## Persistence setup
/// `.modelContainer(for:)` installs a SwiftData container for the listed `@Model` types and
/// injects a `ModelContext` into the environment. Every view below this line can access the
/// database via `@Query` (read) or `@Environment(\.modelContext)` (write).
///
/// ## Startup routing
/// - First launch → `OnboardingView`
/// - Subsequent launches → `TodayView`
/// This branch is driven by a single `@AppStorage` flag, which means SwiftUI reactively
/// re-renders the root when onboarding completes — no manual navigation needed.
@main
struct HabitRApp: App {
    /// First-launch gate. Written to by `OnboardingView` when the user finishes the flow.
    /// Using `@AppStorage` means the value is mirrored in `UserDefaults` and propagated to any
    /// observer automatically, so flipping it triggers the root swap.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// User's theme preference. Defaults to `.dark` (product decision — see CLAUDE.md). Stored
    /// as the raw string so we can round-trip through `UserDefaults` without a custom codec.
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.dark.rawValue

    var body: some Scene {
        // [Interview] `body` is re-evaluated whenever any `@AppStorage`/`@State` it reads
        // changes. That's what lets a theme change in Settings propagate instantly: writing
        // `appThemeRaw` causes this computed property to run again with the new value.
        let theme = AppTheme(rawValue: appThemeRaw) ?? .dark

        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    TodayView()
                } else {
                    OnboardingView()
                }
            }
            // [Interview] `.preferredColorScheme(nil)` is the correct "follow the system"
            // signal — it does NOT mean "no opinion". Any non-nil value propagates down the
            // entire view tree and is honored by system components (nav bar, sheets, etc.).
            .preferredColorScheme(theme.colorScheme)
        }
        // [Interview] One container, two model types. SwiftData infers the schema from the
        // `@Model` classes and creates/migrates the SQLite store on disk automatically on
        // first launch — no manual schema definition required.
        .modelContainer(for: [Habit.self, HabitCompletion.self])
    }
}
