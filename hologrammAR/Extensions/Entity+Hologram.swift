import RealityKit

extension Entity {
    /// Replaces every ModelComponent material in this entity hierarchy.
    ///
    /// Using `any Material` lets this work with UnlitMaterial now and
    /// CustomMaterial/ShaderGraphMaterial later without changing the loader.
    func applyHologramMaterialRecursively(_ material: any Material) {
        if var modelComponent = components[ModelComponent.self] {
            let count = max(modelComponent.materials.count, 1)
            modelComponent.materials = Array(repeating: material, count: count)
            components.set(modelComponent)
        }

        for child in children {
            child.applyHologramMaterialRecursively(material)
        }
    }

    /// Centers an arbitrary imported hierarchy and scales its largest dimension
    /// to `targetMaxDimension` meters.
    func normalizedForHologram(targetMaxDimension: Float) -> Entity {
        let sourceClone = clone(recursive: true)
        let centeredRoot = Entity()
        centeredRoot.name = "NormalizedModelRoot"
        centeredRoot.addChild(sourceClone)

        let initialBounds = sourceClone.visualBounds(
            recursive: true,
            relativeTo: centeredRoot,
            excludeInactive: false
        )

        guard !initialBounds.isEmpty else {
            return centeredRoot
        }

        sourceClone.position -= initialBounds.center

        let centeredBounds = sourceClone.visualBounds(
            recursive: true,
            relativeTo: centeredRoot,
            excludeInactive: false
        )

        let maxDimension = max(
            centeredBounds.extents.x,
            max(centeredBounds.extents.y, centeredBounds.extents.z)
        )

        guard maxDimension > 0.0001 else {
            return centeredRoot
        }

        let scale = targetMaxDimension / maxDimension
        centeredRoot.scale = SIMD3<Float>(repeating: scale)

        return centeredRoot
    }
}
