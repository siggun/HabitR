import SwiftUI

// Settings screen — notification time, restore purchases, rate app, about
// Uses inline @State since there's minimal business logic
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeKit = StoreKitService.shared

    // Persisted settings via UserDefaults
    @State private var reminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @State private var reminderHour = UserDefaults.standard.integer(forKey: "reminderHour")
    @State private var reminderMinute = UserDefaults.standard.integer(forKey: "reminderMinute")
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""

    // Theme override — shares the "appTheme" @AppStorage key with HabitRApp
    // so changes take effect app-wide immediately
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.dark.rawValue

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                appearanceSection
                subscriptionSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
                Button("OK") {}
            } message: {
                Text(restoreMessage)
            }
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Daily Reminder", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, enabled in
                    handleReminderToggle(enabled)
                }

            if reminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: reminderHour) { _, _ in scheduleReminder() }
                .onChange(of: reminderMinute) { _, _ in scheduleReminder() }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            // Picker bound directly to the @AppStorage raw string
            // Uses .menu style to match Apple's own Settings app convention
            Picker("Theme", selection: $appThemeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            if storeKit.isSubscribed {
                Label("HabitR Premium Active", systemImage: "star.fill")
                    .foregroundStyle(Color.accentColor)
            }

            Button("Restore Purchases") {
                Task {
                    await storeKit.restorePurchases()
                    if storeKit.isSubscribed {
                        restoreMessage = "Your subscription has been restored!"
                    } else {
                        restoreMessage = "No active subscription found."
                    }
                    showingRestoreAlert = true
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            // Rate app link — uses the system review prompt
            Button {
                requestAppReview()
            } label: {
                Label("Rate HabitR", systemImage: "star")
            }

            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Made with")
                Spacer()
                Text("❤️ and SwiftUI")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func handleReminderToggle(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "reminderEnabled")

        if enabled {
            Task {
                let granted = await NotificationService.shared.requestPermission()
                if granted {
                    scheduleReminder()
                } else {
                    // Permission denied — turn off toggle and inform user
                    reminderEnabled = false
                    UserDefaults.standard.set(false, forKey: "reminderEnabled")
                }
            }
        } else {
            NotificationService.shared.cancelAllReminders()
        }
    }

    private func scheduleReminder() {
        UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
        NotificationService.shared.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute)
    }

    private func requestAppReview() {
        // In a real app, this would use SKStoreReviewController
        // For now, open the App Store page (replace with real URL after publishing)
        guard let url = URL(string: "https://apps.apple.com/app/habitr") else { return }
        UIApplication.shared.open(url)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Helpers

    private var reminderTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = components.hour ?? 20
                reminderMinute = components.minute ?? 0
            }
        )
    }
}
