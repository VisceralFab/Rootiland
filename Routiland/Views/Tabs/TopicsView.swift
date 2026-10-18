import SwiftUI

// MARK: - Topics Tab
// Four topic cards reproduce the structure of "Homepage topics.svg".
struct TopicsView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var showingAddHabit = false
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(HabitCategory.allCases) { category in
                    NavigationLink(value: category) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: category.symbol)
                                    .font(.title2)
                                    .foregroundStyle(store.accentTheme.color)
                                Spacer()
                                Text("\(store.habits.filter { $0.category == category }.count)")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(category.shortTitle)
                                .font(.system(.headline, design: .rounded))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(RoutilandDesign.cardBackground(darkMode: store.darkMode))
                                .shadow(color: .black.opacity(0.08), radius: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(RoutilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Topics")
        .navigationDestination(for: HabitCategory.self) { category in
            TopicDetailView(category: category)
        }
        .safeAreaInset(edge: .bottom) {
            AddHabitAction { showingAddHabit = true }
        }
        .sheet(isPresented: $showingAddHabit) { HabitEditorView() }
    }
}

// MARK: - Topic Detail
// Lists only the habits in one category and allows adding another habit.
private struct TopicDetailView: View {
    @EnvironmentObject private var store: RoutilandStore
    let category: HabitCategory
    @State private var showingAddHabit = false

    var body: some View {
        List {
            Section(category.title) {
                let matching = store.habits.filter { $0.category == category }
                if matching.isEmpty {
                    ContentUnavailableView("No habits yet", systemImage: category.symbol,
                                           description: Text("Add a habit to this category."))
                } else {
                    ForEach(matching) { habit in HabitRow(habit: habit) }
                }
            }
        }
        .navigationTitle(category.shortTitle)
        .safeAreaInset(edge: .bottom) {
            AddHabitAction { showingAddHabit = true }
        }
        .sheet(isPresented: $showingAddHabit) { HabitEditorView(defaultCategory: category) }
    }
}

#Preview {
    NavigationStack { TopicsView().environmentObject(RoutilandStore()) }
}
