import SwiftUI

// MARK: - Topics
// Presented as a sheet from Track; each category opens a full-screen habit list.
struct TopicsView: View {
    @EnvironmentObject private var store: RootilandStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: HabitCategory?
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(HabitCategory.allCases) { category in
                    Button { selectedCategory = category } label: {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                // Each topic shows in its own fruit color.
                                Image(systemName: category.symbol)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(category.iconColor)
                                    .frame(width: 44, height: 44)
                                    .background(RootilandDesign.iconBackground, in: RoundedRectangle(cornerRadius: 12))
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
                                .fill(RootilandDesign.cardBackground(darkMode: store.darkMode))
                                .shadow(color: .black.opacity(0.08), radius: 0, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Topics")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
            }
        }
        .fullScreenCover(item: $selectedCategory) { category in
            NavigationStack { TopicDetailView(category: category) }
        }
    }
}

// MARK: - Topic Detail
// All habits in the category, including those not scheduled today.
struct TopicDetailView: View {
    @EnvironmentObject private var store: RootilandStore
    @Environment(\.dismiss) private var dismiss
    let category: HabitCategory

    var body: some View {
        let habits = store.habits.filter { $0.category == category }

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your habits").font(.title3.bold())
                    Spacer()
                    Text("\(habits.count) habits")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if habits.isEmpty {
                    ContentUnavailableView("No habits yet", systemImage: category.symbol,
                                           description: Text("Add a habit to this topic with the + button in the tab bar."))
                } else {
                    HabitListCard(habits: habits, allowsManagement: true)
                    Text("Swipe a habit to edit or delete it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .swipeActionsContainer()
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle(category.shortTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
            }
        }
    }
}

#Preview {
    NavigationStack { TopicsView() }
        .environmentObject(RootilandStore())
}

#Preview("Topic habits") {
    NavigationStack { TopicDetailView(category: .movement) }
        .environmentObject(RootilandStore())
}
