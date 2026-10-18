import SwiftUI

// MARK: - Create Habit Sheet
// Opened from the native toolbar + button; this reuses onboarding choices.
struct HabitEditorView: View {
    @EnvironmentObject private var store: RoutilandStore
    @Environment(\.dismiss) private var dismiss
    @State private var category: HabitCategory
    @State private var title: String
    @State private var minutes = 30
    @State private var frequency: HabitFrequency = .daily
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    init(defaultCategory: HabitCategory = .movement) {
        _category = State(initialValue: defaultCategory)
        _title = State(initialValue: defaultCategory.suggestions[0].title)
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
                    .onChange(of: category) { _, newCategory in
                        title = newCategory.suggestions[0].title
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
                Section("Routine") {
                    Picker("Duration", selection: $minutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("1 hour").tag(60)
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    DatePicker("Reminder", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addHabit() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addHabit() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        store.addHabit(Habit(category: category,
                             title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                             durationMinutes: minutes,
                             frequency: frequency,
                             reminderHour: parts.hour ?? 8, reminderMinute: parts.minute ?? 0))
        dismiss()
    }
}

#Preview {
    HabitEditorView().environmentObject(RoutilandStore())
}
