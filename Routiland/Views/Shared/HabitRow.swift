import SwiftUI

// MARK: - Reusable Habit Row
// Shown on Track, Topics and Leafy. Only Track enables daily check-ins.
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
         allowsDeletion: Bool = true, allowsEditing: Bool = true) {
        self.habit = habit
        self.allowsCompletion = allowsCompletion
        self.completionDate = completionDate
        self.allowsDeletion = allowsDeletion
        self.allowsEditing = allowsEditing
    }

    private var checked: Bool { habit.isCompleted(on: completionDate ?? .now) }

    var body: some View {
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
        // Works in a List and, on iOS 27, in any container marked with swipeActionsContainer().
        // Icon-only buttons; the labels are still read by VoiceOver.
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
    }

    private var completionImage: some View {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
    }
}
