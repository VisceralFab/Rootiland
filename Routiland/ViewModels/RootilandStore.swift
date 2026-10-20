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
    @Published private(set) var earnedOrnaments: [LeafyOrnament] = []
    @Published private(set) var isLeafyCheatMode = false
    private var completionHistory: [LeafyCompletion] = []

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
        // The theme can no longer be changed in the app (Settings was removed), so everyone
        // gets the brand green, including anyone who had chosen pink or blue before.
        accentTheme = .green
        darkMode = defaults.bool(forKey: "darkMode")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        measurementSystem = MeasurementSystem(rawValue: defaults.string(forKey: "measurementSystem") ?? "metric") ?? .metric
        if let data = defaults.data(forKey: "leafyCompletionHistory"),
           let saved = try? JSONDecoder().decode([LeafyCompletion].self, from: data) {
            completionHistory = saved
        } else {
            completionHistory = habits.flatMap { habit in
                Set(habit.completedDays).map {
                    LeafyCompletion(habitID: habit.id, day: $0, category: habit.category)
                }
            }
            saveCompletionHistory()
        }
        if let data = defaults.data(forKey: "leafyOrnaments"),
           let saved = try? JSONDecoder().decode([LeafyOrnament].self, from: data) {
            earnedOrnaments = saved
        }
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
        unlockOrnaments()
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
            completionHistory.removeAll { $0.habitID == habit.id && $0.day == key }
            saveCompletionHistory()
            habits[index].completedDays.removeAll { $0 == key }
        } else {
            completionHistory.append(LeafyCompletion(habitID: habit.id, day: key,
                                                     category: habits[index].category))
            saveCompletionHistory()
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
        if !isLoading { unlockOrnaments() }
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
    // Preserve the original first five levels, then earn one level every four completed days.
    static let daysNeededForLevel = [0, 3, 5, 8, 12] + (6...99).map { 12 + ($0 - 5) * 4 }
    static var maxLeafyLevel: Int { daysNeededForLevel.count }

    var completedDayCount: Int { fullyCompletedDays.count }

    var leafyLevel: Int {
        if isLeafyCheatMode { return Self.maxLeafyLevel }
        return earnedLeafyLevel
    }

    private var earnedLeafyLevel: Int {
        (Self.daysNeededForLevel.lastIndex { completedDayCount >= $0 } ?? 0) + 1
    }

    var leafyOrnaments: [LeafyOrnament] {
        if isLeafyCheatMode {
            // A compact showcase of all four models, without fabricating earned rewards.
            return HabitCategory.allCases.enumerated().map { index, category in
                LeafyOrnament(level: 7 + index * 2, category: category)
            }
        }
        return earnedOrnaments
    }

    func enableLeafyCheats() {
        // Session-only: restarting restores the user's real level and earned ornaments.
        isLeafyCheatMode = true
    }

    private func saveCompletionHistory() {
        guard let data = try? JSONEncoder().encode(completionHistory) else { return }
        defaults.set(data, forKey: "leafyCompletionHistory")
    }

    private func unlockOrnaments() {
        guard earnedLeafyLevel >= 7 else { return }
        let completedDays = fullyCompletedDays.sorted()
        for level in stride(from: 7, through: earnedLeafyLevel, by: 2) {
            guard !earnedOrnaments.contains(where: { $0.level == level }) else { continue }
            let lowerIndex = Self.daysNeededForLevel[level - 3] - 1
            let upperIndex = Self.daysNeededForLevel[level - 1] - 1
            guard completedDays.indices.contains(lowerIndex), completedDays.indices.contains(upperIndex) else { continue }
            let start = completedDays[lowerIndex]
            let end = completedDays[upperIndex]
            let interval = completionHistory.filter { $0.day > start && $0.day <= end }
            let counts = Dictionary(grouping: interval, by: \.category).mapValues(\.count)
            // Stable tie-breaking follows the topic order, never dictionary iteration order.
            let winner = HabitCategory.allCases.reduce(HabitCategory.movement) { best, candidate in
                (counts[candidate, default: 0] > counts[best, default: 0]) ? candidate : best
            }
            earnedOrnaments.append(LeafyOrnament(level: level, category: winner))
        }
        earnedOrnaments.sort { $0.level < $1.level }
        if let data = try? JSONEncoder().encode(earnedOrnaments) {
            defaults.set(data, forKey: "leafyOrnaments")
        }
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
