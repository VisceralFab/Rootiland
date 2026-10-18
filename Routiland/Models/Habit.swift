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
// The first prototype uses the day the habit was created as its weekly/monthly reminder day.
enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Every day"
        case .weekly: "Once a week"
        case .monthly: "Once a month"
        }
    }
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

    func isCompleted(on date: Date) -> Bool {
        completedDays.contains(Self.dayKey(for: date))
    }

    // A stable local calendar key avoids double-counting taps within the same day.
    static func dayKey(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - App Accent Color
// Green is the default. Pink and blue are optional colors selectable in Settings.
enum AccentTheme: String, CaseIterable, Codable, Identifiable {
    case green, pink, blue
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .green: Color(red: 109 / 255, green: 212 / 255, blue: 0)
        case .pink: Color(red: 230 / 255, green: 136 / 255, blue: 203 / 255)
        case .blue: Color(red: 0, green: 136 / 255, blue: 1)
        }
    }
}

// The preference applies to physical measurements; habit durations remain time units.
enum MeasurementSystem: String, CaseIterable, Identifiable {
    case metric, imperial

    var id: String { rawValue }
    var title: String { self == .metric ? "Metric" : "Imperial" }
}
