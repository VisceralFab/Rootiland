import Foundation
import SwiftUI

// MARK: - Habit Categories
// These are the four topics shown in the Sketch onboarding and Topics screen.
enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case movement, wellbeing, growth, study

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movement: "Physical Movement"
        case .wellbeing: "Mental Well-being"
        case .growth: "Personal Growth"
        case .study: "Study / Work"
        }
    }

    var shortTitle: String {
        switch self {
        case .movement: "Physical Movement"
        case .wellbeing: "Mental Health"
        case .growth: "Personal Growth"
        case .study: "Study / Work"
        }
    }

    // Use the exact SF Symbols named by the design team.
    var symbol: String {
        switch self {
        case .movement: "dumbbell"
        case .wellbeing: "brain.filled.head.profile"
        case .growth: "medal.fill"
        case .study: "building.classical.columns"
        }
    }

    // The fruit palette each topic is based on.
    private var baseColor: Color {
        switch self {
        case .movement: Color(red: 0xFF / 255, green: 0xAD / 255, blue: 0x4F / 255)   // Mango #FFAD4F
        case .wellbeing: Color(red: 0x70 / 255, green: 0x96 / 255, blue: 0xBB / 255)  // Blue #7096BB
        case .growth: Color(red: 0xEF / 255, green: 0xD4 / 255, blue: 0x6B / 255)     // Banana #EFD46B
        case .study: Color(red: 0xF0 / 255, green: 0x81 / 255, blue: 0x6D / 255)      // Guava #F0816D
        }
    }

    // Each topic's color, used everywhere the topic appears (Timeline, Topics, habit rows
    // and onboarding), whatever the accent theme: a soft pastel of its fruit color.
    var color: Color { baseColor.mix(with: .white, by: 0.35) }

    // Symbols drawn on top of the pastel (tiles, badges, checkmarks): a deep shade of the
    // same fruit, gentler than black and still easy to read.
    var onColor: Color { baseColor.mix(with: .black, by: 0.45) }

    // The fruit color deepened slightly, for icons and outlines on white, where the
    // pastel alone would barely show.
    var deepColor: Color { baseColor.mix(with: .black, by: 0.25) }

    // Colorful topic symbols on a neutral background: the fruit color, a touch deeper
    // so banana and mango stay visible on light grey.
    var iconColor: Color { baseColor.mix(with: .black, by: 0.12) }

    var suggestions: [ActivitySuggestion] {
        switch self {
        case .movement:
            [ActivitySuggestion(title: "Walk", symbol: "figure.walk"),
             ActivitySuggestion(title: "Stretch", symbol: "figure.strengthtraining.functional"),
             ActivitySuggestion(title: "Workout", symbol: "figure.strengthtraining.traditional")]
        case .wellbeing:
            [ActivitySuggestion(title: "Meditate", symbol: "brain.head.profile"),
             ActivitySuggestion(title: "Take a break", symbol: "cup.and.saucer"),
             ActivitySuggestion(title: "Journal", symbol: "book.closed")]
        case .growth:
            [ActivitySuggestion(title: "Read", symbol: "book"),
             ActivitySuggestion(title: "Practice", symbol: "star"),
             ActivitySuggestion(title: "Learn", symbol: "graduationcap")]
        case .study:
            [ActivitySuggestion(title: "Focus", symbol: "timer"),
             ActivitySuggestion(title: "Study", symbol: "books.vertical"),
             ActivitySuggestion(title: "Plan", symbol: "checklist")]
        }
    }
}

struct ActivitySuggestion: Identifiable {
    let title: String
    let symbol: String
    var id: String { title }
}

// MARK: - Habit Frequency
// Weekly and monthly habits repeat on the weekday / day of the month they were created.
// Custom habits happen only on the calendar days the user picked.
enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Once a week"
        case .monthly: "Once a month"
        case .custom: "Specific days"
        }
    }

    // The choices that repeat on their own; onboarding offers only these.
    static let repeatingCases: [HabitFrequency] = [.daily, .weekly, .monthly]
    var repeats: Bool { self != .custom }
}

// MARK: - Habit Model
// Stores a habit and the calendar dates on which it was completed.
struct Habit: Identifiable, Codable {
    var id = UUID()
    var category: HabitCategory
    var title: String
    var durationMinutes: Int
    var frequency: HabitFrequency
    var reminderHour: Int
    var reminderMinute: Int
    var createdAt = Date()
    var completedDays: [String] = []
    // Day keys chosen in the calendar; only used when `frequency` is `.custom`.
    var customDays: [String] = []

    func isCompleted(on date: Date) -> Bool {
        completedDays.contains(Self.dayKey(for: date))
    }

    // Whether the habit is due on the given calendar day.
    func isScheduled(on date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let creationDay = calendar.startOfDay(for: createdAt)
        switch frequency {
        case .daily:
            return day >= creationDay
        case .weekly:
            return day >= creationDay
                && calendar.component(.weekday, from: day) == calendar.component(.weekday, from: creationDay)
        case .monthly:
            return day >= creationDay
                && calendar.component(.day, from: day) == calendar.component(.day, from: creationDay)
        case .custom:
            return customDays.contains(Self.dayKey(for: day))
        }
    }

    // A stable local calendar key avoids double-counting taps within the same day.
    static func dayKey(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // Turns a "yyyy-MM-dd" day key back into the start of that local day.
    static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // "45 min", "1 h", "1 h 30 min"
    static func durationText(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        return minutes % 60 == 0 ? "\(hours) h" : "\(hours) h \(minutes % 60) min"
    }
}

// Habits saved before `customDays` existed have no such key; decode it as empty
// instead of failing, so upgrading never loses the user's habits.
extension Habit {
    private enum CodingKeys: String, CodingKey {
        case id, category, title, durationMinutes, frequency, reminderHour, reminderMinute
        case createdAt, completedDays, customDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        category = try container.decode(HabitCategory.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        frequency = try container.decode(HabitFrequency.self, forKey: .frequency)
        reminderHour = try container.decode(Int.self, forKey: .reminderHour)
        reminderMinute = try container.decode(Int.self, forKey: .reminderMinute)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedDays = try container.decodeIfPresent([String].self, forKey: .completedDays) ?? []
        customDays = try container.decodeIfPresent([String].self, forKey: .customDays) ?? []
    }
}

// MARK: - App Accent Color
// Green is the default. Pink and blue are optional colors selectable in Settings.
enum AccentTheme: String, CaseIterable, Codable, Identifiable {
    case green, pink, blue
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    // The default green is the mid green of the brand palette (PANTONE 15-6423 TCX, #708C3F),
    // dark enough for white labels and green text to stay readable. Pink and blue are the
    // brand colors blended about 18% toward white.
    var color: Color {
        switch self {
        case .green: Color(red: 112 / 255, green: 140 / 255, blue: 63 / 255)
        case .pink: Color(red: 235 / 255, green: 157 / 255, blue: 212 / 255)
        case .blue: Color(red: 46 / 255, green: 157 / 255, blue: 1)
        }
    }
}

// The preference applies to physical measurements; habit durations remain time units.
enum MeasurementSystem: String, CaseIterable, Identifiable {
    case metric, imperial

    var id: String { rawValue }
    var title: String { self == .metric ? "Metric" : "Imperial" }
}
