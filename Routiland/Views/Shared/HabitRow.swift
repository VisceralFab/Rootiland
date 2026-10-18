import SwiftUI

// MARK: - Reusable Habit Row
// Shown on Track, Topics and Leafy. Only Track enables daily check-ins.
struct HabitRow: View {
    @EnvironmentObject private var store: RoutilandStore
    let habit: Habit
    let allowsCompletion: Bool
    let completionDate: Date?
    let allowsDeletion: Bool

    init(habit: Habit, allowsCompletion: Bool = false, completionDate: Date? = nil, allowsDeletion: Bool = true) {
        self.habit = habit
        self.allowsCompletion = allowsCompletion
        self.completionDate = completionDate
        self.allowsDeletion = allowsDeletion
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
                Text("\(store.durationLabel(habit.durationMinutes)) · \(habit.frequency.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if allowsCompletion {
                Button {
                    withAnimation(.smooth) { store.toggleCompletion(habit, on: completionDate ?? .now) }
                } label: {
                    completionImage
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checked ? "Mark \(habit.title) incomplete" : "Complete \(habit.title)")
            } else {
                completionImage
                    .accessibilityLabel(checked ? "Completed" : "Not completed")
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if allowsDeletion {
                Button(role: .destructive) { store.deleteHabit(habit) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var completionImage: some View {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
    }
}
