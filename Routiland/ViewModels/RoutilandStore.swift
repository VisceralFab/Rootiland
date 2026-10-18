import Foundation
import Combine

// MARK: - Shared App State
// One shared object stores the user's habits and settings across all five tabs.
// UserDefaults is sufficient for this initial, offline-only prototype.
@MainActor
final class RoutilandStore: ObservableObject {
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

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        NotificationService.remove(for: habit)
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
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let activeHabits = habits.filter { calendar.startOfDay(for: $0.createdAt) <= day }
        let key = Habit.dayKey(for: date)
        // A day is earned once, at 100%. Later edits never revoke that achievement.
        guard !fullyCompletedDays.contains(key),
              !activeHabits.isEmpty,
              activeHabits.allSatisfy({ $0.isCompleted(on: date) }) else { return }
        fullyCompletedDays.insert(key)
        defaults.set(fullyCompletedDays.sorted(), forKey: "fullyCompletedDays")
    }

    // Today's incomplete checklist keeps yesterday's streak alive until midnight.
    // Calendar arithmetic handles month/year boundaries and daylight-saving changes.
    func currentStreak(asOf date: Date = .now) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        if !fullyCompletedDays.contains(Habit.dayKey(for: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while fullyCompletedDays.contains(Habit.dayKey(for: day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var totalCompletions: Int { habits.reduce(0) { $0 + $1.completedDays.count } }
    var completedToday: Int { habits.filter { $0.isCompleted(on: .now) }.count }

    // MARK: - Leafy Progression
    // Prototype balancing: 3 check-ins unlock each level; maximum level is 5.
    // Change these numbers here when the game progression has been finalized.
    private let checkInsPerLevel = 3
    var leafyLevel: Int { min(5, totalCompletions / checkInsPerLevel + 1) }
    var levelProgress: Double {
        leafyLevel == 5 ? 1 : Double(totalCompletions % checkInsPerLevel) / Double(checkInsPerLevel)
    }
    var checkInsToNextLevel: Int {
        leafyLevel == 5 ? 0 : checkInsPerLevel - totalCompletions % checkInsPerLevel
    }

    func durationLabel(_ minutes: Int) -> String {
        return "\(minutes) min"
    }
}
