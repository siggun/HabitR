# HabitR

A clean, minimal habit tracker for iOS. Track daily and weekly habits, visualize your progress with a GitHub-style contribution grid, maintain streaks, and build consistency — all with your data stored locally on your device. Free for up to 3 habits, with an optional subscription to unlock unlimited habits.

## Screenshots

Coming soon — screenshots will be added before App Store submission.

## Prerequisites

- **Xcode 15.0+** (required for SwiftData and iOS 17 target)
- **macOS 14.0+ (Sonoma)** or later
- **Apple Developer Program membership** ($99/year) — required for App Store submission and physical device testing beyond the 7-day free provisioning limit
- A **free Apple ID** works for simulator testing only

## Getting Started

1. Clone the repo:
   ```bash
   git clone https://github.com/siggun/habitr.git
   cd habitr
   ```
2. Open `HabitR.xcodeproj` in Xcode
3. Select a simulator (iPhone 15 Pro recommended) or a connected device as the build target
4. Build and run with **Cmd+R**

## Running on a Physical Device

1. Connect your iPhone via USB, or set up wireless debugging (Xcode > Window > Devices and Simulators > pair over network)
2. Select your device as the build target in the Xcode toolbar
3. On your iPhone, go to **Settings > General > VPN & Device Management** and trust the developer certificate
4. Build and run (**Cmd+R**) — note that a paid Apple Developer account is required for on-device testing beyond the 7-day free provisioning limit

## Testing In-App Purchases

HabitR uses a `Products.storekit` StoreKit Configuration file for local testing in the Xcode simulator. No App Store Connect account is required for testing.

1. Open the Xcode scheme: **Product > Scheme > Edit Scheme** (or **Cmd+Shift+,**)
2. Select **Run** in the left sidebar
3. Go to the **Options** tab
4. Under **StoreKit Configuration**, select `Products.storekit`
5. Build and run — purchases are now simulated locally with no real charges

StoreKit Testing in Xcode simulates the full purchase flow including subscription management, cancellation, and restore. You can also use **Debug > StoreKit > Manage Transactions** to inspect and clear test transactions.

## Testing Notifications

Local notifications work in the iOS Simulator, but the alert style may differ from a real device (banners vs alerts). To test:

1. Run the app and go through onboarding (or Settings) to set a reminder time
2. Set the reminder to 1-2 minutes in the future
3. Background the app (**Cmd+Shift+H**)
4. Wait for the notification to fire

For full testing including banners, sounds, and notification grouping, test on a physical device.

## Testing Checklist

Before submitting to the App Store, verify:

- [ ] All habits can be created, edited, and deleted
- [ ] Both completion modes work: toggle (tap on/off) and counter (tap to increment)
- [ ] Check-offs persist after app restart
- [ ] Streaks calculate correctly across day and month boundaries
- [ ] GitHub-style grid shows correct color intensity based on completions
- [ ] Calendar view shows correct completion status per day
- [ ] Tapping a past day in calendar correctly adds/removes a completion and recalculates streak
- [ ] 3-habit free limit triggers paywall
- [ ] Subscription purchase, restore, and cancellation all work (via StoreKit Testing)
- [ ] Notifications schedule and fire correctly
- [ ] Notification permission denied is handled gracefully
- [ ] Onboarding only shows on first launch
- [ ] Light and dark mode both look correct
- [ ] App doesn't crash on any screen rotation or background/foreground cycle

## App Store Submission Guide

### 1. Enroll in Apple Developer Program

Go to [developer.apple.com](https://developer.apple.com), click "Enroll", and pay $99/year. Approval can take 24-48 hours.

### 2. Create App Store Connect Listing

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps** > **+** > **New App**
3. Enter the app name (**HabitR**), select your bundle ID, and set the primary language

### 3. Prepare App Store Metadata

- **App name:** HabitR
- **Subtitle:** Include keywords like "habit tracker" or "daily routine" (e.g., "Simple Daily Habit Tracker")
- **Description:** Focus on benefits, not features — what the user gets, not what the app does
- **Keywords:** Comma-separated, 100 character limit. Research competitor keywords (e.g., "habit,tracker,streak,routine,daily,goals,productivity,health")
- **Category:** Health & Fitness (primary), Productivity (secondary)
- **Privacy policy URL:** Required — see step 4
- **Support URL:** Your GitHub repo or a simple support page

### 4. Create a Privacy Policy

HabitR stores all data locally and doesn't collect or share user data. Create a simple privacy policy:

1. Create `docs/privacy-policy.md` in this repo
2. Enable GitHub Pages in repo settings (Settings > Pages > Source: main branch, /docs folder)
3. Link the published URL in App Store Connect

### 5. Take Screenshots

Required sizes:
- **6.7"** — iPhone 15 Pro Max (1290 × 2796)
- **5.5"** — iPhone 8 Plus (1242 × 2208)

Use the Xcode simulator to capture 3-5 screenshots showing:
1. Today view with habits checked off
2. GitHub-style grid visualization
3. Calendar view
4. Paywall screen
5. Onboarding

### 6. Create an App Icon

- 1024×1024 PNG, no transparency, no rounded corners (Apple adds those)
- Keep it simple — a checkmark or similar symbol in the app's green accent color

### 7. Archive and Upload

1. In Xcode, select **Any iOS Device** as the build target
2. **Product > Archive**
3. Once archived, click **Distribute App** > **App Store Connect** > **Upload**
4. Wait 15-30 minutes for the build to finish processing in App Store Connect

### 8. Select the Build

In App Store Connect, go to your app listing, scroll to the **Build** section, and select the uploaded build.

### 9. Submit for Review

Click **Submit for Review**. Apple's review typically takes 24-48 hours.

**Common rejection reasons to avoid:**
- Paywall must have a "Restore Purchases" button ✅ (included)
- Subscription terms must be clearly displayed before purchase ✅ (included)
- App must be functional without a subscription ✅ (3 free habits)
- Privacy policy URL must be valid and accessible
- App must not crash — test thoroughly

## TestFlight Beta Testing (Optional but Recommended)

Before submitting for public review, distribute to beta testers via TestFlight:

1. Upload a build to App Store Connect (same archive process as above)
2. Go to the **TestFlight** tab in App Store Connect
3. Add internal testers (your Apple ID, friends, team members)
4. Testers receive a link to install via the TestFlight app
5. Collect feedback, fix bugs, upload a new build, repeat

You can distribute to up to 10,000 external beta testers.

## Project Structure

```
HabitR/
├── CLAUDE.md              # AI assistant context file
├── README.md              # This file
├── LICENSE                # MIT license
├── .gitignore
├── HabitR/
│   ├── App/               # App entry point and configuration
│   ├── Models/            # SwiftData models (Habit, HabitCompletion)
│   ├── ViewModels/        # View models (only where needed)
│   ├── Views/             # All SwiftUI views, organized by feature
│   │   ├── Onboarding/    # First-launch onboarding flow
│   │   ├── Home/          # Today's habits list
│   │   ├── Detail/        # Habit detail with grid and calendar
│   │   ├── Settings/      # App settings
│   │   └── Paywall/       # Subscription paywall
│   ├── Services/          # Notification and StoreKit services
│   └── Resources/         # Assets and StoreKit config
└── HabitR.xcodeproj/
```

## Architecture Decisions

- **SwiftData** over CoreData — modern, declarative persistence that integrates naturally with SwiftUI. Fewer boilerplate files, no .xcdatamodeld, and macro-based model definitions.
- **Lightweight MVVM** — ViewModels only for screens with real business logic (TodayView, PaywallView). Simple screens use inline @State to avoid unnecessary abstraction.
- **No third-party dependencies** — Apple-only frameworks keep the app lightweight, reduce maintenance burden, and avoid supply chain risk. StoreKit 2, UserNotifications, and SwiftData cover all our needs.
- **Business logic separation** — Streak calculations, habit limits, and paywall rules are kept cleanly separated from UI to support a future Android port.

## Roadmap

### v1.1 (Planned)
- Apple's built-in App Analytics for usage data (free, no SDK needed)
- Weekly/monthly stats graphs
- iCloud sync via CloudKit

### v2 (Future)
- Android port (Kotlin or React Native)
- Widgets for home screen
- Social/accountability features

## License

MIT — see [LICENSE](LICENSE) for details.
