import RealityKit
import UIKit

@MainActor
final class HologramMaterialFactory {
    private let bodyBlue = UIColor(
        red: 0.16,
        green: 0.66,
        blue: 1.00,
        alpha: 1.0
    )

    private let iceBlue = UIColor(
        red: 0.76,
        green: 0.95,
        blue: 1.00,
        alpha: 1.0
    )

    /// The main translucent body. PBR gives the USDZ's geometry enough
    /// surface response to remain legible, while emission keeps it looking
    /// self-illuminated rather than like blue plastic.
    func makeBodyMaterial(opacity: Float = 0.42) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()

        material.baseColor = .init(tint: bodyBlue)
        material.roughness = 0.28
        material.metallic = 0.06

        material.emissiveColor = .init(color: bodyBlue)
        material.emissiveIntensity = 1.55

        material.blending = .transparent(
            opacity: .init(floatLiteral: opacity)
        )

        material.readsDepth = true
        material.writesDepth = false

        return material
    }

    /// A second copy of the model is drawn as wireframe just outside the body.
    /// This restores edge/mesh definition without CustomMaterial, which is
    /// unavailable on visionOS.
    func makeWireframeMaterial(opacity: Float = 0.44) -> UnlitMaterial {
        var material = UnlitMaterial(
            color: iceBlue,
            applyPostProcessToneMap: false
        )

        material.blending = .transparent(
            opacity: .init(floatLiteral: opacity)
        )
        material.triangleFillMode = .lines
        material.readsDepth = true
        material.writesDepth = false

        return material
    }

    /// Used for rings, scan bands, and glow shells. Emissive intensity lets
    /// these read as light rather than opaque geometry.
    func makeLightMaterial(
        opacity: Float,
        intensity: Float,
        whiteMix: CGFloat = 0.55
    ) -> PhysicallyBasedMaterial {
        let color = blend(bodyBlue, iceBlue, amount: whiteMix)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = 0.15
        material.metallic = 0.0
        material.emissiveColor = .init(color: color)
        material.emissiveIntensity = intensity
        material.blending = .transparent(
            opacity: .init(floatLiteral: opacity)
        )
        material.readsDepth = true
        material.writesDepth = false

        return material
    }

    private func blend(
        _ a: UIColor,
        _ b: UIColor,
        amount: CGFloat
    ) -> UIColor {
        let t = min(max(amount, 0), 1)

        var ar: CGFloat = 0
        var ag: CGFloat = 0
        var ab: CGFloat = 0
        var aa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0

        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

        return UIColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: aa + (ba - aa) * t
        )
    }
}
