import SwiftUI
import RealityKit
import UIKit
import OSLog

// MARK: - Leafy 3D Island
// Loads the current USDZ island and supports drag-to-rotate and pinch-to-zoom.
struct IslandRealityView: View {
    let modelName: String
    let level: Int
    var ornaments: [LeafyOrnament] = []
    var height: CGFloat = 330

    @State private var persistentZoom: Float = 1.0
    @State private var gestureZoom: Float = 1.0
    @State private var orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @State private var dragStartOrientation: simd_quatf?
    @State private var sceneRoot: Entity?
    @State private var isLoading = false

    private var effectiveZoom: Float {
        min(max(persistentZoom * gestureZoom, 0.6), 3.0)
    }

    private var appearanceID: String {
        "\(level):" + ornaments.map { "\($0.level)-\($0.category.rawValue)" }.joined(separator: ",")
    }

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            let scene = Entity()
            scene.name = "LeafyIslandScene"

            let camera = PerspectiveCamera()
            camera.position = SIMD3<Float>(0, 1.8, 4.6)
            camera.look(at: SIMD3<Float>(0, 0.0, 0), from: camera.position, relativeTo: nil)
            scene.addChild(camera)

            let light = DirectionalLight()
            light.light.intensity = 18000
            light.position = SIMD3<Float>(-2, 4, 3)
            light.look(at: .zero, from: light.position, relativeTo: nil)
            scene.addChild(light)

            let scalableRoot = Entity()
            scalableRoot.name = "ScalableIslandRoot"

            scalableRoot.scale = SIMD3<Float>(repeating: effectiveZoom)
            scalableRoot.orientation = orientation
            scene.addChild(scalableRoot)
            content.add(scene)
            sceneRoot = scalableRoot
        } update: { content in
            guard let scene = content.entities.first(where: { $0.name == "LeafyIslandScene" }),
                  let scalableRoot = scene.findEntity(named: "ScalableIslandRoot") else { return }
            scalableRoot.scale = SIMD3<Float>(repeating: effectiveZoom)
            scalableRoot.orientation = orientation
        }
        // RealityView's creation closure is not a reliable place to react to level changes.
        // Explicitly refresh the entities when the scene is ready or its rewards change.
        .task(id: "\(modelName):\(appearanceID):\(sceneRoot?.id ?? 0)") {
            await refreshIsland()
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if dragStartOrientation == nil {
                        dragStartOrientation = orientation
                    }
                    guard let startingOrientation = dragStartOrientation else { return }

                    // Drag values are measured from the beginning of the gesture. Compose
                    // them with that exact starting quaternion so repeated drags never snap.
                    let yaw = simd_quatf(
                        angle: Float(value.translation.width) * 0.01,
                        axis: SIMD3<Float>(0, 1, 0)
                    )
                    let pitch = simd_quatf(
                        angle: Float(value.translation.height) * 0.01,
                        axis: SIMD3<Float>(1, 0, 0)
                    )
                    orientation = simd_normalize(yaw * startingOrientation * pitch)
                }
                .onEnded { _ in
                    dragStartOrientation = nil
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    gestureZoom = Float(value.magnification)
                }
                .onEnded { value in
                    persistentZoom = min(max(persistentZoom * Float(value.magnification), 0.6), 3.0)
                    gestureZoom = 1.0
                }
        )
        .frame(height: height)
        .overlay {
            if isLoading {
                ProgressView("Loading Leafy…")
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Three dimensional Leafy island, level \(level)")
    }

    @MainActor
    private func refreshIsland() async {
        guard let sceneRoot else { return }
        isLoading = true
        // Stage the complete island off-screen; cancelled older loads never replace it.
        let appearance = Entity()
        appearance.name = "LeafyAppearance_Level\(level)"
        if let model = await IslandModelLibrary.load(modelName) {
            guard !Task.isCancelled else { return }
            centerModel(model)
            appearance.addChild(model)
            await addDecorations(to: appearance, islandHeight: model.visualBounds(relativeTo: nil).extents.y)
        } else {
            guard !Task.isCancelled else { return }
            appearance.addChild(IslandFallback.make(level: level))
            await addDecorations(to: appearance, islandHeight: 0.9, hasIslandAsset: false)
        }
        guard !Task.isCancelled else { return }
        for child in Array(sceneRoot.children) { child.removeFromParent() }
        sceneRoot.addChild(appearance)
        isLoading = false
    }

    // This helper recenters and scales the imported USDZ so it fits nicely in the box.
    private func centerModel(_ entity: Entity) {
        let box = entity.visualBounds(relativeTo: nil)
        let dimensions = box.extents
        let largest = max(dimensions.x, max(dimensions.y, dimensions.z))
        if largest > 0.0001 {
            let factor: Float = 2.2 / largest
            entity.scale = SIMD3<Float>(repeating: factor)
            entity.position = -box.center * factor
        }
    }

    @MainActor
    private func addDecorations(to root: Entity, islandHeight: Float, hasIslandAsset: Bool = true) async {
        guard level >= 2 else { return }
        let decorationReferenceHeight = islandHeight * 0.5
        let treeHeight = level >= 5 ? islandHeight * 0.8 : decorationReferenceHeight
        let treeName = level >= 5 ? "Banana_Tree_1020172120_texture" : "Banana plant"
        var treePoint = IslandModelLibrary.groundSlots[0]
        if !hasIslandAsset { treePoint.y = -0.02 }
        if let tree = await IslandModelLibrary.load(treeName) {
            guard !Task.isCancelled else { return }
            place(tree, at: treePoint, size: treeHeight, byHeight: true,
                  horizontalScale: level >= 5 ? 1.1 : 1)
            tree.name = level >= 5 ? "LeafyBananaTree" : "LeafyBananaPlant"
            root.addChild(tree)
        }

        guard level >= 7 else { return }
        let unlocked = ornaments.filter { $0.level <= level }.sorted { $0.level < $1.level }
        // Extra rewards use smaller models so even a mature island has room for them.
        let ornamentSize = decorationReferenceHeight * (unlocked.count > 24 ? 0.18 : unlocked.count > 8 ? 0.24 : 0.32)
        for (index, reward) in unlocked.prefix(47).enumerated() {
            guard !Task.isCancelled else { return }
            guard let ornament = await IslandModelLibrary.load(reward.category.ornamentModelName) else { continue }
            guard !Task.isCancelled else { return }
            var point = IslandModelLibrary.groundSlots[index + 1]
            if !hasIslandAsset { point.y = -0.02 }
            place(ornament, at: point, size: ornamentSize, byHeight: false)
            ornament.name = "LeafyReward_Level\(reward.level)_\(reward.category.rawValue)"
            root.addChild(ornament)
        }
    }

    @MainActor
    private func place(_ model: Entity, at point: SIMD3<Float>, size: Float, byHeight: Bool,
                       horizontalScale: Float = 1) {
        let bounds = model.visualBounds(relativeTo: nil)
        let dimensions = bounds.extents
        let reference = byHeight ? dimensions.y : max(dimensions.x, max(dimensions.y, dimensions.z))
        guard reference > 0.0001 else { return }
        let factor = size / reference
        let scale = SIMD3<Float>(factor * horizontalScale, factor, factor * horizontalScale)
        model.scale = scale
        // USDZ origins differ: anchor each actual mesh base to the island's surface.
        model.position = point - SIMD3<Float>(bounds.center.x * scale.x,
                                             bounds.min.y * scale.y + 0.006,
                                             bounds.center.z * scale.z)
    }
}

// Cache source entities so repeated rewards share meshes and textures.
@MainActor
private enum IslandModelLibrary {
    private static var models: [String: Entity] = [:]
    private static let logger = Logger(subsystem: "Rootiland", category: "LeafyModels")

    static func load(_ name: String) async -> Entity? {
        if let cached = models[name] { return cached.clone(recursive: true) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models") else {
            logger.error("Missing bundled USDZ: \(name, privacy: .public)")
            return nil
        }
        do {
            let entity = try await Entity(contentsOf: url)
            guard !Task.isCancelled else { return nil }
            models[name] = entity
            return entity.clone(recursive: true)
        } catch {
            if !Task.isCancelled {
                logger.error("Cannot load \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
    }

    // Ground intersections sampled from leafy_island.usdz after normalization to 2.2 units.
    // Slot 0 anchors the tree; three rings provide room for every reward through level 99.
    // Actual surface heights avoid floating models on the island's uneven terrain.
    static let groundSlots: [SIMD3<Float>] = [
        SIMD3<Float>(0.00000, 0.24881, -0.08000),
        SIMD3<Float>(0.24042, 0.29199, 0.16042),
        SIMD3<Float>(-0.24042, 0.24924, 0.16042),
        SIMD3<Float>(-0.24042, 0.27277, -0.32042),
        SIMD3<Float>(0.24042, 0.28915, -0.32042),
        SIMD3<Float>(0.34000, 0.25219, -0.08000),
        SIMD3<Float>(0.00000, 0.24882, 0.26000),
        SIMD3<Float>(-0.34000, 0.30783, -0.08000),
        SIMD3<Float>(-0.00000, 0.24891, -0.42000),
        SIMD3<Float>(0.50000, 0.24915, -0.08000),
        SIMD3<Float>(0.46194, 0.25068, 0.11134),
        SIMD3<Float>(0.35355, 0.24616, 0.27355),
        SIMD3<Float>(0.19134, 0.24627, 0.38194),
        SIMD3<Float>(0.00000, 0.24648, 0.42000),
        SIMD3<Float>(-0.19134, 0.24613, 0.38194),
        SIMD3<Float>(-0.35355, 0.24607, 0.27355),
        SIMD3<Float>(-0.46194, 0.25065, 0.11134),
        SIMD3<Float>(-0.50000, 0.24966, -0.08000),
        SIMD3<Float>(-0.46194, 0.24196, -0.27134),
        SIMD3<Float>(-0.35355, 0.24716, -0.43355),
        SIMD3<Float>(-0.19134, 0.26168, -0.54194),
        SIMD3<Float>(-0.00000, 0.25023, -0.58000),
        SIMD3<Float>(0.19134, 0.24622, -0.54194),
        SIMD3<Float>(0.35355, 0.24203, -0.43355),
        SIMD3<Float>(0.46194, 0.26479, -0.27134),
        SIMD3<Float>(0.65000, 0.27741, -0.08000),
        SIMD3<Float>(0.62785, 0.27989, 0.08823),
        SIMD3<Float>(0.56292, 0.28313, 0.24500),
        SIMD3<Float>(0.45962, 0.28285, 0.37962),
        SIMD3<Float>(0.32500, 0.27428, 0.48292),
        SIMD3<Float>(0.16823, 0.27665, 0.54785),
        SIMD3<Float>(0.00000, 0.27464, 0.57000),
        SIMD3<Float>(-0.16823, 0.27479, 0.54785),
        SIMD3<Float>(-0.32500, 0.29798, 0.48292),
        SIMD3<Float>(-0.45962, 0.27153, 0.37962),
        SIMD3<Float>(-0.56292, 0.27924, 0.24500),
        SIMD3<Float>(-0.62785, 0.27174, 0.08823),
        SIMD3<Float>(-0.65000, 0.27651, -0.08000),
        SIMD3<Float>(-0.62785, 0.27508, -0.24823),
        SIMD3<Float>(-0.56292, 0.27036, -0.40500),
        SIMD3<Float>(-0.45962, 0.27165, -0.53962),
        SIMD3<Float>(-0.32500, 0.31719, -0.64292),
        SIMD3<Float>(-0.16823, 0.26178, -0.70785),
        SIMD3<Float>(-0.00000, 0.25956, -0.73000),
        SIMD3<Float>(0.16823, 0.28375, -0.70785),
        SIMD3<Float>(0.32500, 0.27267, -0.64292),
        SIMD3<Float>(0.45962, 0.28078, -0.53962),
        SIMD3<Float>(0.56292, 0.27067, -0.40500),
        SIMD3<Float>(0.62785, 0.27478, -0.24823),
    ]
}

// MARK: - Procedural Placeholder Model
// This is only used if the USDZ file is missing.
@MainActor
private enum IslandFallback {
    static func make(level: Int) -> Entity {
        let root = Entity()
        let soil = SimpleMaterial(color: UIColor(red: 0.42, green: 0.28, blue: 0.18, alpha: 1), roughness: 1, isMetallic: false)
        let grass = SimpleMaterial(color: UIColor(red: 0.42, green: 0.73, blue: 0.27, alpha: 1), roughness: 1, isMetallic: false)

        func piece(_ mesh: MeshResource, _ material: SimpleMaterial,
                   at point: SIMD3<Float>) -> ModelEntity {
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = point
            return entity
        }

        let rock = piece(.generateCone(height: 0.76, radius: 1.1), soil,
                         at: SIMD3<Float>(0, -0.50, 0))
        rock.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(rock)
        root.addChild(piece(.generateCylinder(height: 0.18, radius: 1.10), grass,
                            at: SIMD3<Float>(0, -0.11, 0)))
        return root
    }
}

#Preview {
    IslandRealityView(modelName: "leafy_island", level: 2)
}
