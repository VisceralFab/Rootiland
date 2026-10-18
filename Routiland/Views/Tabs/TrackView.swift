import SwiftUI

// MARK: - Track Tab
// A focused checklist for today's habits.
struct TrackView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var showingAddHabit = false

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: .now), by: 60)) { context in
            trackContent(at: context.date)
        }
        .background(RoutilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Track")
        .safeAreaInset(edge: .bottom) {
            AddHabitAction { showingAddHabit = true }
        }
        .sheet(isPresented: $showingAddHabit) { HabitEditorView() }
    }

    private func trackContent(at now: Date) -> some View {
        let streak = store.currentStreak(asOf: now)
        let securedToday = store.fullyCompletedDays.contains(Habit.dayKey(for: now))

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(streak > 0 ? Color.orange : .secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current streak")
                            .font(.headline)
                        Text(streak == 1 ? "1 day" : "\(streak) days")
                            .font(.title2.bold().monospacedDigit())
                        Text(securedToday
                             ? "Today's streak is secured."
                             : "Complete all of today's habits to keep your streak going.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Today's habits").font(.title3.bold())
                        Text("\(store.completedToday) of \(store.habits.count) completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !store.habits.isEmpty {
                        Text("\(completionPercentage)%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(store.accentTheme.color)
                    }
                }
                if store.habits.isEmpty {
                    ContentUnavailableView("Start a habit", systemImage: "checklist", description: Text("Add your first habit to begin tracking progress."))
                } else {
                    VStack(spacing: 6) {
                        ForEach(store.habits) { habit in
                            HabitRow(habit: habit, allowsCompletion: true)
                            if habit.id != store.habits.last?.id { Divider() }
                        }
                    }
                    .padding(15)
                    .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(20)
        }
    }

    private var completionPercentage: Int {
        guard !store.habits.isEmpty else { return 0 }
        return Int(Double(store.completedToday) / Double(store.habits.count) * 100)
    }

}

#Preview {
    NavigationStack { TrackView().environmentObject(RoutilandStore()) }
}
