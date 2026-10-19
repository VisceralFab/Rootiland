import SwiftUI
import RealityKit
import UIKit
import ImageIO

// MARK: - Leafy 3D Island
// Loads the current USDZ island and supports drag-to-rotate and pinch-to-zoom.
struct IslandRealityView: View {
    let modelName: String
    let level: Int
    var height: CGFloat = 330

    @State private var persistentZoom: Float = 1.0
    @State private var gestureZoom: Float = 1.0
    @State private var orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @State private var dragStartOrientation: simd_quatf?

    private var effectiveZoom: Float {
        min(max(persistentZoom * gestureZoom, 0.6), 3.0)
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

            let scalableRoot = Entity()
            scalableRoot.name = "ScalableIslandRoot"

            // The HDRI sky lights the island and drives its reflections. The light entity sits
            // outside the rotating root, so reflections stay fixed to the sky as the island turns.
            if let environment = await IslandSkyEnvironment.load() {
                let skyLight = Entity()
                skyLight.name = "SkyLight"
                skyLight.components.set(ImageBasedLightComponent(source: .single(environment),
                                                                 intensityExponent: IslandSkyEnvironment.intensityExponent))
                scene.addChild(skyLight)
                scalableRoot.components.set(ImageBasedLightReceiverComponent(imageBasedLight: skyLight))
            } else {
                // Without the HDRI, fall back to a single key light.
                let light = DirectionalLight()
                light.light.intensity = 18000
                light.position = SIMD3<Float>(-2, 4, 3)
                light.look(at: .zero, from: light.position, relativeTo: nil)
                scene.addChild(light)
            }

            if let assetURL = Bundle.main.url(forResource: modelName, withExtension: "usdz", subdirectory: "Models"),
               let model = try? await Entity(contentsOf: assetURL) {
                centerModel(model)
                scalableRoot.addChild(model)
            } else {
                scalableRoot.addChild(IslandFallback.make(level: level))
            }

            scalableRoot.scale = SIMD3<Float>(repeating: effectiveZoom)
            scalableRoot.orientation = orientation
            scene.addChild(scalableRoot)
            content.add(scene)
        } update: { content in
            guard let scene = content.entities.first(where: { $0.name == "LeafyIslandScene" }),
                  let scalableRoot = scene.findEntity(named: "ScalableIslandRoot") else { return }
            scalableRoot.scale = SIMD3<Float>(repeating: effectiveZoom)
            scalableRoot.orientation = orientation
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
        .accessibilityLabel("Three dimensional Leafy island, level \(level)")
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
}

// MARK: - HDRI Sky Lighting
// Poly Haven "Kloofendal 48d Partly Cloudy (Pure Sky)", 2K, CC0 licence.
// Converting the HDR into lighting textures takes a moment, so the result is
// cached and shared by the Leafy preview and the full-screen island.
@MainActor
private enum IslandSkyEnvironment {
    static let fileName = "kloofendal_48d_partly_cloudy_puresky_2k"
    // Brightness on a log2 scale: 0 uses the HDR as-is, +1 doubles it, -1 halves it.
    static let intensityExponent: Float = 0

    private static var cached: EnvironmentResource?

    static func load() async -> EnvironmentResource? {
        if let cached { return cached }
        // ShouldAllowFloat keeps the HDR's full brightness range instead of clamping it to 8-bit.
        let options = [kCGImageSourceShouldAllowFloat: true] as CFDictionary
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "hdr", subdirectory: "Models"),
              let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let image = CGImageSourceCreateImageAtIndex(source, 0, options),
              let environment = try? await EnvironmentResource(equirectangular: image, withName: fileName) else {
            return nil
        }
        cached = environment
        return environment
    }
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
