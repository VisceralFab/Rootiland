import Foundation
import UserNotifications

// MARK: - Habit Notifications
// Only asks permission after the onboarding explains why reminders are useful.
// Uses local calendar notifications: no account or remote server is required.
enum NotificationService {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleAll(_ habits: [Habit]) async {
        for habit in habits { await schedule(habit) }
    }

    static func schedule(_ habit: Habit) async {
        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.title)"
        content.body = "A small step today helps Leafy grow."
        content.sound = .default

        var parts = DateComponents()
        parts.hour = habit.reminderHour
        parts.minute = habit.reminderMinute
        switch habit.frequency {
        case .daily: break
        case .weekly:
            parts.weekday = Calendar.current.component(.weekday, from: habit.createdAt)
        case .monthly:
            parts.day = Calendar.current.component(.day, from: habit.createdAt)
        }

        let request = UNNotificationRequest(identifier: identifier(for: habit),
                                            content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func remove(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: habit)])
    }

    static func removeAll(for habits: [Habit]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: habits.map(identifier(for:)))
    }

    private static func identifier(for habit: Habit) -> String { "habit.\(habit.id.uuidString)" }
}
