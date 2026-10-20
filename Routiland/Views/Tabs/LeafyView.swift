import SwiftUI

// MARK: - Leafy Tab
struct LeafyView: View {
    @EnvironmentObject private var store: RootilandStore
    @State private var showingIsland = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 12) {
                    islandPreview
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                        .onTapGesture { showingIsland = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Open the island full screen")
                        .accessibilityAction { showingIsland = true }

                    HStack {
                        Label("Level \(store.leafyLevel)", systemImage: "leaf.fill")
                            .font(.headline)
                        Spacer()
                        Text(store.isLeafyFullyGrown ? "Fully grown" : daysToGrowText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: store.levelProgress)
                        .tint(store.accentTheme.color)
                        .accessibilityLabel("Leafy level progress")

                    Text("Tap to explore the island full screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 12) {
                    Label(store.isLeafyFullyGrown ? "Quest complete" : "Next quest",
                          systemImage: store.isLeafyFullyGrown ? "checkmark.seal.fill" : "sparkles")
                        .font(.headline)
                        .foregroundStyle(store.accentTheme.color)
                    Text(store.isLeafyFullyGrown
                         ? "Leafy has reached the maximum level!"
                         : "Reach level \(store.leafyLevel + 1) to unlock new decorations for Leafy!")
                        .font(.title3.bold())
                    Text(store.isLeafyFullyGrown
                         ? "Keep completing your habits and caring for your island."
                         : "Complete all of a day's habits to count it. \(store.completedDayCount) of \(RootilandStore.daysNeededForLevel[store.leafyLevel]) days done.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: store.levelProgress)
                        .tint(store.accentTheme.color)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RootilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(20)
        }
        .background(RootilandDesign.canvas(darkMode: store.darkMode))
        // The system large title replaces the old hard-coded header and adapts to dark mode.
        .navigationTitle("Leafy")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showingIsland) {
            LeafyIslandFullScreenView()
        }
    }

    private var daysToGrowText: String {
        store.daysToNextLevel == 1 ? "1 day to grow" : "\(store.daysToNextLevel) days to grow"
    }

    @ViewBuilder
    private var islandPreview: some View {
        // Keep a single live RealityKit renderer while the full-screen scene is open.
        if showingIsland {
            Color.clear.frame(height: 330)
        } else {
            IslandRealityView(modelName: "leafy_island", level: store.leafyLevel)
        }
    }
}

private struct LeafyIslandFullScreenView: View {
    @EnvironmentObject private var store: RootilandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            IslandRealityView(
                modelName: "leafy_island",
                level: store.leafyLevel,
                height: geometry.size.height
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(RootilandDesign.canvas(darkMode: store.darkMode))
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .top, alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(.primary)
            .accessibilityLabel("Close")
            .padding(.leading, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    NavigationStack { LeafyView().environmentObject(RootilandStore()) }
}
