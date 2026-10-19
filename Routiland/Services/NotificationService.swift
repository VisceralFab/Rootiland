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

    // Reads the current system permission without prompting the user.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
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

        if habit.frequency == .custom {
            await scheduleCustomDays(habit, content: content)
            return
        }

        var parts = DateComponents()
        parts.hour = habit.reminderHour
        parts.minute = habit.reminderMinute
        switch habit.frequency {
        case .daily, .custom: break
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

    // Picked days don't follow a pattern, so each upcoming one gets its own one-time reminder.
    // iOS keeps at most 64 pending reminders per app, so only the next few per habit are queued.
    private static func scheduleCustomDays(_ habit: Habit, content: UNNotificationContent) async {
        let calendar = Calendar.current
        let upcoming = habit.customDays
            .compactMap(Habit.date(fromDayKey:))
            .compactMap { calendar.date(bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: $0) }
            .filter { $0 > .now }
            .sorted()
            .prefix(maxRemindersPerCustomHabit)

        for date in upcoming {
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: identifier(for: habit, day: Habit.dayKey(for: date)),
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private static let maxRemindersPerCustomHabit = 14

    static func remove(for habit: Habit) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers(for: habit))
    }

    static func removeAll(for habits: [Habit]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: habits.flatMap(identifiers(for:)))
    }

    private static func identifier(for habit: Habit) -> String { "habit.\(habit.id.uuidString)" }
    private static func identifier(for habit: Habit, day: String) -> String { "habit.\(habit.id.uuidString).\(day)" }

    // Every reminder a habit may have pending, whatever its frequency.
    private static func identifiers(for habit: Habit) -> [String] {
        [identifier(for: habit)] + habit.customDays.map { identifier(for: habit, day: $0) }
    }
}
