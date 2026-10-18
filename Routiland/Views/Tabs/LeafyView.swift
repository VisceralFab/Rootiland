import SwiftUI

// MARK: - Leafy Tab
struct LeafyView: View {
    @EnvironmentObject private var store: RoutilandStore
    @State private var showingIsland = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Leafy")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.black)

                VStack(spacing: 12) {
                    islandPreview
                        .contentShape(Rectangle())
                        .onTapGesture { showingIsland = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Open the island full screen")
                        .accessibilityAction { showingIsland = true }

                    HStack {
                        Label("Level \(store.leafyLevel)", systemImage: "leaf.fill")
                            .font(.headline)
                        Spacer()
                        Text(store.leafyLevel == 5 ? "Fully grown" : "\(store.checkInsToNextLevel) check-ins to grow")
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 12) {
                    Label(store.leafyLevel == 5 ? "Quest complete" : "Next quest", systemImage: store.leafyLevel == 5 ? "checkmark.seal.fill" : "sparkles")
                        .font(.headline)
                        .foregroundStyle(store.accentTheme.color)
                    Text(store.leafyLevel == 5
                         ? "Leafy has reached the maximum level!"
                         : "Reach level \(store.leafyLevel + 1) to unlock new decorations for Leafy!")
                        .font(.title3.bold())
                    Text(store.leafyLevel == 5
                         ? "Keep completing your habits and caring for your island."
                         : "Complete your habits: \(store.checkInsToNextLevel) more check-ins to the next level.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: store.levelProgress)
                        .tint(store.accentTheme.color)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoutilandDesign.cardBackground(darkMode: store.darkMode), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(20)
        }
        .background(RoutilandDesign.canvas(darkMode: store.darkMode))
        .navigationTitle("Leafy")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingIsland) {
            LeafyIslandFullScreenView()
        }
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
    @EnvironmentObject private var store: RoutilandStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            IslandRealityView(
                modelName: "leafy_island",
                level: store.leafyLevel,
                height: geometry.size.height
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(RoutilandDesign.canvas(darkMode: store.darkMode))
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
    NavigationStack { LeafyView().environmentObject(RoutilandStore()) }
}
