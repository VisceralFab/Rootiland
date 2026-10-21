import SwiftUI

// MARK: - Topics
// The selector filters the list in place, without opening another modal.
struct TopicsView: View {
    @EnvironmentObject private var store: RootilandStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: HabitCategory

    init(initialCategory: HabitCategory = .movement) {
        _selectedCategory = State(initialValue: initialCategory)
    }

    var body: some View {
        let habits = store.habits.filter { $0.category == selectedCategory }

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topicSelector
                        .id("topicSelector")

                    HStack {
                        Text("Your habits").font(.title3.bold())
                        Spacer()
                        Text(habits.count == 1 ? "1 habit" : "\(habits.count) habits")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if habits.isEmpty {
                        ContentUnavailableView("No habits yet", systemImage: selectedCategory.symbol,
                                               description: Text("Add a habit to this topic with the + button in the tab bar."))
                    } else {
                        HabitListCard(habits: habits, allowsManagement: true)
                            .id(selectedCategory)
                        Text("Swipe a habit to edit or delete it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .swipeActionsContainer()
            .onChange(of: selectedCategory) { _, _ in
                proxy.scrollTo("topicSelector", anchor: .top)
            }
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
            }
        }
    }

    private var topicSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)

            HStack(spacing: 12) {
                Text("Category")
                    .font(.body)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Menu {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(HabitCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbol).tag(category)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedCategory.symbol)
                        Text(selectedCategory.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.body)
                    .foregroundStyle(store.accentTheme.color)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                .accessibilityLabel("Category")
                .accessibilityValue(selectedCategory.title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RootilandDesign.cardBackground(darkMode: store.darkMode),
                        in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

#Preview {
    NavigationStack { TopicsView() }
        .environmentObject(RootilandStore())
}
