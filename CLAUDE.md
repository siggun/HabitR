# HabitR — Project Context for Claude Code

## Overview
HabitR is a freemium iOS habit tracker app. Users can track daily/weekly habits, view progress via a GitHub-style contribution grid, maintain streaks, and edit past completions via a calendar view. Free tier allows 3 habits; unlimited habits require a subscription ($2.99/month or $19.99/year).

## Tech Stack
- **Language:** Swift
- **UI:** SwiftUI (no UIKit unless absolutely necessary)
- **Persistence:** SwiftData (NOT CoreData) — iOS 17+
- **Payments:** StoreKit 2
- **Notifications:** UserNotifications framework
- **Target:** iOS 17+
- **Dependencies:** None — Apple-only frameworks, zero third-party packages

## Architecture
**Lightweight MVVM** — only create ViewModel files for screens with real business logic:
- `HabitListViewModel` — manages habit CRUD, streak calculations, free tier limit enforcement
- `PaywallViewModel` — manages StoreKit 2 subscription state, purchase/restore flows

Simple screens (Settings, Onboarding) keep logic inline with @State. Don't create a ViewModel just for pattern consistency.

## Key Models

### Habit (SwiftData @Model)
- `id: UUID`
- `name: String`
- `emoji: String`
- `frequency: HabitFrequency` (enum: .daily, .weekly)
- `completionMode: CompletionMode` (enum: .toggle, .counter)
- `dailyTarget: Int` (for counter mode, e.g. 8 glasses of water)
- `createdAt: Date`
- `completions: [HabitCompletion]` (relationship)

### HabitCompletion (SwiftData @Model)
- `id: UUID`
- `date: Date` (normalized to start of day)
- `count: Int` (1 for toggle mode, variable for counter mode)
- `habit: Habit` (inverse relationship)

**Relationship:** Habit has many HabitCompletions. One completion record per day per habit. Counter mode increments the `count` field rather than creating multiple records.

## Monetization Logic
- Free tier: 3 habits maximum
- Check habit count before allowing creation of a new habit
- If count >= 3 and user is not subscribed, show PaywallView
- Subscription products: `habitr.monthly` ($2.99/mo), `habitr.yearly` ($19.99/yr)
- Products.storekit file enables local testing without App Store Connect
- Always provide "Restore Purchases" (App Store requirement)

## File Organization
```
HabitR/App/          → App entry point, @main
HabitR/Models/       → SwiftData model definitions
HabitR/ViewModels/   → HabitListViewModel, PaywallViewModel
HabitR/Views/        → All UI, organized by feature area
HabitR/Services/     → NotificationService, StoreKitService
HabitR/Resources/    → Assets.xcassets, Products.storekit
```

## Coding Conventions
- **200 line file limit** — break up large files
- **SF Symbols** for all icons (no custom images except app icon)
- **System fonts only** — no custom fonts
- **Green accent color** — used throughout for the habit/success theme
- **Comments** — explain Swift/SwiftUI concepts for learning purposes
- **Haptic feedback** — UIImpactFeedbackGenerator on check-off actions
- **Animations** — subtle scale animation on completion toggle

## Edge Cases Already Handled
- **Midnight rollover:** Dates normalized to start of day using Calendar.startOfDay(for:)
- **Streak across month boundaries:** Streak calculation walks backwards day by day, not by month
- **Deleting a habit mid-streak:** Cascade delete removes all completions
- **Notification permission denied:** Graceful fallback, no crash, settings prompt
- **StoreKit flows:** Purchase success, failure, cancellation, and restore all handled
- **Editing past completions:** Recalculates streak after any change
- **Counter mode overflow:** Allows exceeding daily target (shows as exceeded)
- **Counter mode decrement to zero:** Treats as incomplete, removes completion record
- **Grid visualization:** Empty squares shown for days before habit creation date

## Known SwiftData Quirks
- On iOS 17.0-17.2, SwiftData can have issues with complex predicates on relationships. Use simple predicates and filter in Swift where needed.
- Cascade delete on relationships should be explicitly specified via @Relationship(deleteRule: .cascade).
- Dates in SwiftData predicates can behave unexpectedly — normalize all dates to start of day before storing.

## What NOT to Add in v1
- ❌ Stats graphs / charts
- ❌ Social / accountability features
- ❌ Custom themes / colors
- ❌ Home screen widgets
- ❌ iCloud sync
- ❌ Analytics SDK (will use Apple's free App Analytics post-launch)
- ❌ Any third-party dependencies
- ❌ Apple Watch app
- ❌ iPad-specific layouts

## v1.1 Roadmap (Context Only)
- Apple App Analytics (free, no SDK)
- Weekly/monthly stats graphs
- iCloud sync via CloudKit
- Future v2: Android port — business logic is separated from UI to make this easier
