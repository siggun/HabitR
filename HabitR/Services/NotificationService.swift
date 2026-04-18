import Foundation
import os
import UserNotifications

private let log = Logger(subsystem: "HabitR", category: "NotificationService")

/// Thin wrapper around `UNUserNotificationCenter` for scheduling the app's daily habit reminder.
///
/// Scope is intentionally narrow — the app currently schedules exactly one recurring local
/// notification. If additional notification types are introduced (per-habit reminders, weekly
/// summaries, etc.), extract an identifier enum and parameterize the schedule/cancel methods.
///
/// ## Why local, not push?
/// Local notifications require no backend, no APNs certificate, and no network at delivery time.
/// They're delivered by the OS even when the app is suspended. Push would be overkill for a
/// self-contained habit tracker.
///
/// ## Permissions
/// Authorization status is OS-owned. We never cache our own "granted" flag — we re-query via
/// `checkPermissionStatus()` on every access to stay in sync with Settings.app toggles.
final class NotificationService {
    /// App-wide shared instance. State-free; the singleton exists only to save callers from
    /// repeatedly instantiating a trivial wrapper.
    static let shared = NotificationService()
    private init() {}

    /// Stable identifier used across schedule/cancel. Hard-coded because the app currently
    /// schedules exactly one reminder — see class-level doc comment for the expansion path.
    private static let reminderIdentifier = "habitr.daily.reminder"

    // MARK: - Permission

    /// Request the three notification capabilities we use.
    ///
    /// - `.alert`: banner / lock-screen display.
    /// - `.badge`: app icon badge counter (reserved for future use).
    /// - `.sound`: audible notification.
    ///
    /// - Returns: `true` if the user granted (or had previously granted) permission. `false` on
    ///   denial or error. Callers should handle `false` by showing a soft-prompt pointing the
    ///   user to Settings — **never** attempt to re-request after a denial; iOS will no-op and
    ///   the system prompt won't reappear.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            log.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Fetch the current authorization status. Use this to branch UI (e.g. hide the reminder
    /// toggle, show a "Go to Settings" CTA) rather than caching the result of a prior request.
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Scheduling

    /// Schedule the daily reminder at `hour:minute` local time.
    ///
    /// Implementation detail: we always cancel first. `UNCalendarNotificationTrigger` is
    /// identifier-keyed — adding a new request with the same identifier overwrites, but being
    /// explicit makes the intent obvious and side-steps any surprise if iOS ever changes that
    /// behavior.
    ///
    /// - Parameters:
    ///   - hour:   24-hour clock hour (0–23).
    ///   - minute: 0–59.
    func scheduleDailyReminder(hour: Int, minute: Int) {
        cancelAllReminders()

        let content = UNMutableNotificationContent()
        content.title = "Time to check your habits!"
        content.body = "Don't break your streak — open HabitR and log today's progress."
        content.sound = .default

        // [Interview] Supplying only hour/minute to DateComponents (no year/month/day) combined
        // with `repeats: true` tells the system "fire whenever the current time matches these
        // components" — i.e. daily. This is the canonical pattern for daily repeating reminders.
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("Failed to schedule notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Remove the scheduled daily reminder. Idempotent — calling when nothing is scheduled is a
    /// no-op. We target only our own identifier so any future notification types aren't nuked.
    func cancelAllReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }
}
