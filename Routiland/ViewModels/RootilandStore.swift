import Foundation
import Combine

// MARK: - Shared App State
// One shared object stores the user's habits and settings across all five tabs.
// UserDefaults is sufficient for this initial, offline-only prototype.
@MainActor
final class RootilandStore: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet {
            guard !isLoading else { return }
            saveHabits()
            recordCompletedDay(on: .now)
        }
    }
    @Published var finishedOnboarding = false {
        didSet { defaults.set(finishedOnboarding, forKey: "finishedOnboarding") }
    }
    @Published var accentTheme: AccentTheme = .green {
        didSet { defaults.set(accentTheme.rawValue, forKey: "accentTheme") }
    }
    @Published var darkMode = false {
        didSet { defaults.set(darkMode, forKey: "darkMode") }
    }
    @Published var notificationsEnabled = false {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var measurementSystem: MeasurementSystem = .metric {
        didSet { defaults.set(measurementSystem.rawValue, forKey: "measurementSystem") }
    }

    @Published private(set) var fullyCompletedDays: Set<String> = []

    private let defaults: UserDefaults
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Retrieve saved data before presenting the first screen.
        if let data = defaults.data(forKey: "savedHabits"),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
        finishedOnboarding = defaults.bool(forKey: "finishedOnboarding")
        accentTheme = AccentTheme(rawValue: defaults.string(forKey: "accentTheme") ?? "green") ?? .green
        darkMode = defaults.bool(forKey: "darkMode")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        measurementSystem = MeasurementSystem(rawValue: defaults.string(forKey: "measurementSystem") ?? "metric") ?? .metric
        if let savedDays = defaults.stringArray(forKey: "fullyCompletedDays") {
            fullyCompletedDays = Set(savedDays)
        } else {
            // Recover existing successful days when upgrading from the old app.
            let calendar = Calendar.current
            for key in Set(habits.flatMap(\.completedDays)) {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3,
                      let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { continue }
                recordCompletedDay(on: date)
            }
        }
        isLoading = false
        recordCompletedDay(on: .now)
    }

    private func saveHabits() {
        guard let encoded = try? JSONEncoder().encode(habits) else { return }
        defaults.set(encoded, forKey: "savedHabits")
    }

    func addHabit(_ habit: Habit) {
        habits.append(habit)
        if notificationsEnabled {
            Task { await NotificationService.schedule(habit) }
        }
    }

    func updateHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        // Clear the old reminders first: days removed from a custom schedule must stop firing.
        NotificationService.remove(for: habits[index])
        habits[index] = habit
        if notificationsEnabled {
            Task { await NotificationService.schedule(habit) }
        }
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        NotificationService.remove(for: habit)
    }

    // MARK: - Notification Permission
    // Reminders are switched on and off in the iPhone's Settings app, so the app simply
    // mirrors the system permission.

    /// Shows the system permission prompt; used the first time, before Settings has an entry for the app.
    func enableNotifications() async -> Bool {
        let allowed = await NotificationService.requestPermission()
        notificationsEnabled = allowed
        if allowed { await NotificationService.scheduleAll(habits) }
        return allowed
    }

    // Permission can change in the Settings app at any time, so this runs whenever the app becomes active.
    func syncNotificationPermission() async {
        let authorized = await NotificationService.isAuthorized()
        if authorized != notificationsEnabled {
            notificationsEnabled = authorized
        }
        if authorized {
            // Also tops up custom-day reminders, which are only queued a few days ahead.
            await NotificationService.scheduleAll(habits)
        } else {
            NotificationService.removeAll(for: habits)
        }
    }

    func toggleCompletion(_ habit: Habit, on date: Date = .now) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let key = Habit.dayKey(for: date)
        if habits[index].completedDays.contains(key) {
            habits[index].completedDays.removeAll { $0 == key }
        } else {
            habits[index].completedDays.append(key)
        }
        recordCompletedDay(on: date)
    }

    private func recordCompletedDay(on date: Date) {
        // Only the habits due that day count, so weekly and specific-day habits
        // never stand in the way on their days off.
        let dueHabits = habits.filter { $0.isScheduled(on: date) }
        let key = Habit.dayKey(for: date)
        // A day is earned once, at 100%. Later edits never revoke that achievement.
        guard !fullyCompletedDays.contains(key),
              !dueHabits.isEmpty,
              dueHabits.allSatisfy({ $0.isCompleted(on: date) }) else { return }
        fullyCompletedDays.insert(key)
        defaults.set(fullyCompletedDays.sorted(), forKey: "fullyCompletedDays")
    }

    // The habits due today, in the order they were added.
    var todaysHabits: [Habit] { habits.filter { $0.isScheduled(on: .now) } }
    var completedToday: Int { todaysHabits.filter { $0.isCompleted(on: .now) }.count }
    var isTodayComplete: Bool { fullyCompletedDays.contains(Habit.dayKey(for: .now)) }

    // MARK: - Leafy Progression
    // Leafy grows with completed days: days on which every habit due was checked off.
    // The days don't need to be in a row, and a completed day is never taken away.
    // Each entry is the total number of completed days needed to reach that level
    // (index 0 is level 1). Change the numbers here to rebalance the game.
    static let daysNeededForLevel = [0, 3, 5, 8, 12]
    static var maxLeafyLevel: Int { daysNeededForLevel.count }

    var completedDayCount: Int { fullyCompletedDays.count }

    var leafyLevel: Int {
        (Self.daysNeededForLevel.lastIndex { completedDayCount >= $0 } ?? 0) + 1
    }

    var isLeafyFullyGrown: Bool { leafyLevel == Self.maxLeafyLevel }

    // Progress from the current level's threshold to the next one, from 0 to 1.
    var levelProgress: Double {
        guard !isLeafyFullyGrown else { return 1 }
        let current = Self.daysNeededForLevel[leafyLevel - 1]
        let next = Self.daysNeededForLevel[leafyLevel]
        return Double(completedDayCount - current) / Double(next - current)
    }

    var daysToNextLevel: Int {
        guard !isLeafyFullyGrown else { return 0 }
        return Self.daysNeededForLevel[leafyLevel] - completedDayCount
    }

    func durationLabel(_ minutes: Int) -> String {
        Habit.durationText(minutes)
    }
}
