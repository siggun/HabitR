import Foundation
import UserNotifications

// Handles scheduling and managing the daily habit reminder notification
// Uses Apple's UserNotifications framework for local notifications
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    /// Request permission to show notifications
    /// Returns true if permission was granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    /// Check current notification authorization status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Schedule a daily reminder at the user's chosen time
    /// Removes any existing reminder before scheduling the new one
    func scheduleDailyReminder(hour: Int, minute: Int) {
        // Remove old reminders first
        cancelAllReminders()

        let content = UNMutableNotificationContent()
        content.title = "Time to check your habits!"
        content.body = "Don't break your streak — open HabitR and log today's progress."
        content.sound = .default

        // DateComponents trigger repeats daily at the specified time
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "habitr.daily.reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Remove all scheduled reminders
    func cancelAllReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["habitr.daily.reminder"])
    }
}
