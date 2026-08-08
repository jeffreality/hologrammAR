import Foundation
import RealityKit
import UIKit

@MainActor
final class HologramAssetLibrary {
    private(set) var assets: [HologramAsset] = []

    /// Loads every .usdz in a bundle subdirectory called "Holograms".
    ///
    /// If Xcode flattens your resources, it also checks the bundle root.
    /// Keep unrelated USDZ files out of the app bundle for this POC.
    func preload() async {
        assets.removeAll()

        var urls = Bundle.main.urls(
            forResourcesWithExtension: "usdz",
            subdirectory: "Holograms"
        ) ?? []

        if urls.isEmpty {
            urls = Bundle.main.urls(
                forResourcesWithExtension: "usdz",
                subdirectory: nil
            ) ?? []
        }

        let sortedURLs = urls.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }

        for url in sortedURLs {
            do {
                let entity = try await Entity(contentsOf: url)
                assets.append(
                    HologramAsset(
                        name: url.deletingPathExtension().lastPathComponent,
                        source: entity
                    )
                )
            } catch {
                print("Failed to preload \(url.lastPathComponent): \(error)")
            }
        }

        // Makes the POC testable before you add any USDZ assets.
        if assets.isEmpty {
            assets.append(
                HologramAsset(
                    name: "FallbackSphere",
                    source: makeFallbackEntity()
                )
            )
        }
    }

    func randomAsset(excluding currentName: String?) -> HologramAsset {
        let candidates = assets.filter { $0.name != currentName }

        if let random = candidates.randomElement() {
            return random
        }

        return assets.randomElement()!
    }

    private func makeFallbackEntity() -> Entity {
        let material = SimpleMaterial(color: .white, isMetallic: false)
        return ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [material]
        )
    }
}
