# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

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

## Home Screen Design
The home screen uses a **2-column card grid** layout (not a list). Each card shows:
- Circular checkmark button → transforms to habit emoji when completed
- Habit name + month/year label
- Mini contribution grid preview (~6 weeks, solid on/off colors)
- Delete via long-press context menu

Components: `HabitCardView.swift`, `MiniGridView.swift` in `Views/Home/`

## Theme & Appearance
- **Blue accent color** — vibrant "Dodger Blue" (#3D78F5 light, #598CFF dark)
- **Dark mode default** — app defaults to Dark via `AppTheme` enum in `HabitRApp.swift`
- **Custom dark background** — slightly grey (#1A1B1D), not pitch black
- **Two-tone branding** — "Habit" in default text color, "R" in accent blue
- **Theme selector** in Settings → Appearance (system/light/dark via `@AppStorage`)
- **Grid colors** — solid on/off, no intensity gradient

## Coding Conventions
- **200 line file limit** — break up large files
- **SF Symbols** for all icons (no custom images except app icon)
- **System fonts only** — no custom fonts
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

## v1.1 Changes Already Shipped
- ✅ Dark mode default with theme selector (system/light/dark)
- ✅ Two-tone "HabitR" branding in nav bar
- ✅ Card grid home screen with mini contribution grids
- ✅ Blue accent color (replaced green)
- ✅ Slightly grey dark mode background (not pitch black)
- ✅ Solid on/off grid colors (no intensity gradient)

## v1.1 Roadmap (Remaining)
- Apple App Analytics (free, no SDK)
- Weekly/monthly stats graphs
- iCloud sync via CloudKit
- Future v2: Android port — business logic is separated from UI to make this easier
