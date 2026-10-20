import SwiftUI

// MARK: - Reusable Habit Row
// Track enables daily check-ins; Topics enables editing and deletion.
struct HabitRow: View {
    @EnvironmentObject private var store: RootilandStore
    let habit: Habit
    let allowsCompletion: Bool
    let completionDate: Date?
    let allowsDeletion: Bool
    let allowsEditing: Bool
    @State private var showingEditor = false
    // Bumped each time the habit is checked off, to play the confetti.
    @State private var confettiTrigger = 0

    init(habit: Habit, allowsCompletion: Bool = false, completionDate: Date? = nil,
         allowsDeletion: Bool = false, allowsEditing: Bool = false) {
        self.habit = habit
        self.allowsCompletion = allowsCompletion
        self.completionDate = completionDate
        self.allowsDeletion = allowsDeletion
        self.allowsEditing = allowsEditing
    }

    private var checked: Bool { habit.isCompleted(on: completionDate ?? .now) }

    @ViewBuilder
    var body: some View {
        // An empty swipeActions modifier still lets the row slide on iOS.
        // Checklist rows must never receive the modifier at all.
        if allowsDeletion || allowsEditing {
            rowContent
            .swipeActions(edge: .trailing) {
                if allowsDeletion {
                    Button(role: .destructive) { store.deleteHabit(habit) } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                }
                if allowsEditing {
                    Button { showingEditor = true } label: {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                    .tint(.gray)
                }
            }
            .sheet(isPresented: $showingEditor) { HabitEditorView(habit: habit) }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.category.symbol)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.headline)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? .secondary : .primary)
                Text("\(store.durationLabel(habit.durationMinutes)) · \(habit.frequency.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if allowsCompletion {
                Button {
                    if !checked { confettiTrigger += 1 }
                    withAnimation(.smooth) { store.toggleCompletion(habit, on: completionDate ?? .now) }
                } label: {
                    completionImage
                }
                .buttonStyle(.plain)
                // A tighter burst that stays within the row.
                .overlay { ConfettiBurst(trigger: confettiTrigger, spread: 12) }
                .sensoryFeedback(.success, trigger: confettiTrigger)
                .accessibilityLabel(checked ? "Mark \(habit.title) incomplete" : "Complete \(habit.title)")
            } else {
                completionImage
                    .accessibilityLabel(checked ? "Completed" : "Not completed")
            }
        }
        .padding(.vertical, 4)
    }

    private var completionImage: some View {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
    }
}

// Shared appearance for today's checklist and each topic's complete habit list.
// Management is explicitly enabled only by topic screens.
struct HabitListCard: View {
    @EnvironmentObject private var store: RootilandStore
    let habits: [Habit]
    var allowsCompletion = false
    var completionDate: Date?
    var allowsManagement = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(habits) { habit in
                HabitRow(habit: habit, allowsCompletion: allowsCompletion, completionDate: completionDate,
                         allowsDeletion: allowsManagement, allowsEditing: allowsManagement)
                    .background(RootilandDesign.cardBackground(darkMode: store.darkMode))
                    .clipped()
                if habit.id != habits.last?.id { Divider() }
            }
        }
        .padding(15)
        .background(RootilandDesign.cardBackground(darkMode: store.darkMode),
                    in: RoundedRectangle(cornerRadius: 20))
    }
}
