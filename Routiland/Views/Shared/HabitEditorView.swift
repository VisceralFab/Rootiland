import SwiftUI

// MARK: - Create / Edit Habit Sheet
// Opened from the + button to create a habit, or from a row's Edit action to change one.
struct HabitEditorView: View {
    @EnvironmentObject private var store: RootilandStore
    @Environment(\.dismiss) private var dismiss
    // When set, the sheet edits this habit and keeps its id, start date and history.
    private let existingHabit: Habit?
    @State private var category: HabitCategory
    @State private var title: String
    @State private var minutes: Int
    @State private var frequency: HabitFrequency
    // Days picked in the calendar when the frequency is "Specific days".
    @State private var customDates: Set<DateComponents>
    @State private var reminderTime: Date
    @State private var showingDayPicker: Bool

    init(defaultCategory: HabitCategory = .movement) {
        existingHabit = nil
        category = defaultCategory
        title = defaultCategory.suggestions[0].title
        minutes = 30
        frequency = .daily
        customDates = []
        reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
        showingDayPicker = false
    }

    init(habit: Habit) {
        existingHabit = habit
        category = habit.category
        title = habit.title
        minutes = habit.durationMinutes
        frequency = habit.frequency
        customDates = Set(habit.customDays.compactMap(Habit.date(fromDayKey:)).map(Self.calendarComponents))
        reminderTime = Calendar.current.date(bySettingHour: habit.reminderHour, minute: habit.reminderMinute,
                                             second: 0, of: .now) ?? .now
        showingDayPicker = false
    }

    // MultiDatePicker matches selections by their components, so these must include the
    // calendar and era exactly as the picker creates them.
    private static func calendarComponents(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
    }

    private var sortedCustomDates: [Date] {
        customDates.compactMap { Calendar.current.date(from: $0) }.sorted()
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (frequency != .custom || !customDates.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    .onChange(of: category) { oldCategory, newCategory in
                        // Only swap the name if it is empty or still the previous topic's suggestion,
                        // so a name the user typed is never overwritten.
                        let current = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if current.isEmpty || oldCategory.suggestions.contains(where: { $0.title == current }) {
                            title = newCategory.suggestions[0].title
                        }
                    }
                }
                Section("Habit") {
                    TextField("Habit name", text: $title)
                        .textInputAutocapitalization(.words)
                    Menu {
                        ForEach(category.suggestions) { item in
                            Button(item.title, systemImage: item.symbol) { title = item.title }
                        }
                    } label: {
                        Label("Use a suggestion", systemImage: "sparkles")
                    }
                }
                Section {
                    DurationWheelPicker(minutes: $minutes)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Duration")
                        .accessibilityValue(Habit.durationText(minutes))
                } header: {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(Habit.durationText(minutes)).textCase(nil)
                    }
                }
                Section("Routine") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .onChange(of: frequency) { _, newFrequency in
                        // Open the calendar straight away the first time "Specific days" is picked.
                        if newFrequency == .custom && customDates.isEmpty { showingDayPicker = true }
                    }
                    if frequency == .custom {
                        daysBar
                    }
                    DatePicker("Reminder", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }
            .sheet(isPresented: $showingDayPicker) {
                HabitDaysSheet(dates: $customDates)
            }
            .navigationTitle(existingHabit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingHabit == nil ? "Add" : "Save") { saveHabit() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // The bar that opens the monthly calendar and summarizes the chosen days.
    private var daysBar: some View {
        Button { showingDayPicker = true } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    Text(daysSummary)
                        .foregroundStyle(customDates.isEmpty ? Color.accentColor : .secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            } label: {
                Label("Days", systemImage: "calendar")
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityHint("Opens a calendar to choose the days")
    }

    // "Choose days", "20 Oct, 22 Oct" or "6 days".
    private var daysSummary: String {
        let dates = sortedCustomDates
        switch dates.count {
        case 0: return "Choose days"
        case 1...3: return dates.map { $0.formatted(.dateTime.day().month(.abbreviated).locale(RootilandDesign.locale)) }
            .joined(separator: ", ")
        default: return "\(dates.count) days"
        }
    }

    private func saveHabit() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let days = frequency == .custom ? sortedCustomDates.map(Habit.dayKey(for:)) : []
        if var habit = existingHabit {
            habit.category = category
            habit.title = name
            habit.durationMinutes = minutes
            habit.frequency = frequency
            habit.customDays = days
            habit.reminderHour = parts.hour ?? 8
            habit.reminderMinute = parts.minute ?? 0
            store.updateHabit(habit)
        } else {
            store.addHabit(Habit(category: category,
                                 title: name,
                                 durationMinutes: minutes,
                                 frequency: frequency,
                                 reminderHour: parts.hour ?? 8, reminderMinute: parts.minute ?? 0,
                                 customDays: days))
        }
        dismiss()
    }
}

// MARK: - Specific Days Calendar
// A monthly calendar where any number of upcoming days can be toggled on and off.
// Shared by the habit editor and onboarding.
struct HabitDaysSheet: View {
    @Binding var dates: Set<DateComponents>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MultiDatePicker("Days", selection: $dates, in: Calendar.current.startOfDay(for: .now)...)
                        .labelsHidden()
                    Text(dates.isEmpty
                         ? "Tap the days you want to do this habit."
                         : (dates.count == 1 ? "1 day selected" : "\(dates.count) days selected"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Choose Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { dates.removeAll() }
                        .disabled(dates.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    HabitEditorView().environmentObject(RootilandStore())
}
