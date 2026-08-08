import Foundation
import RealityKit
import UIKit
import simd

@MainActor
final class HologramSceneController {
    let anchor: AnchorEntity

    private let assetLibrary = HologramAssetLibrary()
    private let materialFactory = HologramMaterialFactory()

    // aboveHand anchor axes:
    //   +Y -> toward the user's head
    //   +Z -> toward the ground
    //
    // V2.1 keeps the stable aboveHand behavior that worked on-device and moves
    // the effect one inch toward the palm center.
    private let presentationRoot = Entity()
    private let hologramRoot = Entity()
    private let modelSpinRoot = Entity()
    private let ringA = Entity()
    private let ringB = Entity()
    private let scanFieldRoot = Entity()
    private let scanSweepRoot = Entity()
    private let glowRoot = Entity()

    private var ghostModelRoot: Entity?

    private var currentAssetName: String?
    private var targetVisible = false
    private var visibility: Float = 0
    private var isPrepared = false
    private var pendingOpenPose = false

    private var modelAngle: Float = 0
    private var ringAAngle: Float = 0
    private var ringBAngle: Float = 0
    private var scanPhase: Float = 0
    private var elapsedTime: Float = 0

    private let targetModelSize: Float = 0.115

    init() {
        anchor = AnchorEntity(
            .hand(.left, location: .aboveHand),
            trackingMode: .predicted
        )

        anchor.name = "LeftAboveHandAnchor"
        presentationRoot.name = "PresentationRoot"
        hologramRoot.name = "HologramRoot"
        modelSpinRoot.name = "ModelSpinRoot"
        ringA.name = "RingA"
        ringB.name = "RingB"
        scanFieldRoot.name = "ScanFieldRoot"
        scanSweepRoot.name = "ScanSweepRoot"
        glowRoot.name = "GlowRoot"

        // Convert conventional USD Y-up content to world-up in the
        // aboveHand anchor coordinate space.
        presentationRoot.orientation = simd_quatf(
            angle: -.pi / 2,
            axis: SIMD3<Float>(1, 0, 0)
        )

        // One inch toward the user/head = away from the finger pads and toward
        // the center of the palm for the natural "show your palm" pose.
        presentationRoot.position.y = 0.0254

        // Slight lift above the physical hand.
        presentationRoot.position.z = -0.015

        anchor.addChild(presentationRoot)
        presentationRoot.addChild(hologramRoot)

        hologramRoot.addChild(modelSpinRoot)
        hologramRoot.addChild(scanFieldRoot)
        hologramRoot.addChild(scanSweepRoot)
        hologramRoot.addChild(ringA)
        hologramRoot.addChild(ringB)
        hologramRoot.addChild(glowRoot)

        hologramRoot.components.set(OpacityComponent(opacity: 0))
        hologramRoot.isEnabled = false
    }

    func prepare() async {
        await assetLibrary.preload()
        buildEffects()
        isPrepared = true

        if pendingOpenPose {
            pendingOpenPose = false
            showRandomHologram()
        }
    }

    func handle(_ pose: HandPose) {
        switch pose {
        case .open:
            guard !targetVisible else { return }

            guard isPrepared else {
                pendingOpenPose = true
                return
            }

            showRandomHologram()

        case .closed:
            pendingOpenPose = false
            targetVisible = false

        case .unknown, .intermediate:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        let dt = Float(min(deltaTime, 1.0 / 20.0))
        elapsedTime += dt

        modelAngle += dt * 0.55
        ringAAngle += dt * 0.95
        ringBAngle -= dt * 0.72
        scanPhase += dt * 0.34

        modelSpinRoot.orientation = simd_quatf(
            angle: modelAngle,
            axis: SIMD3<Float>(0, 1, 0)
        )

        let ringABaseTilt = simd_quatf(
            angle: .pi / 7,
            axis: SIMD3<Float>(1, 0, 0)
        )

        let ringBBaseTilt = simd_quatf(
            angle: -.pi / 5,
            axis: simd_normalize(SIMD3<Float>(1, 0, 1))
        )

        ringA.orientation =
            simd_quatf(
                angle: ringAAngle,
                axis: SIMD3<Float>(0, 1, 0)
            )
            * ringABaseTilt

        ringB.orientation =
            simd_quatf(
                angle: ringBAngle,
                axis: SIMD3<Float>(0, 1, 0)
            )
            * ringBBaseTilt

        updateScanSweep()
        updateGhosting()

        let speed: Float = targetVisible ? 4.8 : 7.5
        let target: Float = targetVisible ? 1.0 : 0.0

        visibility = move(
            visibility,
            toward: target,
            maxDelta: speed * dt
        )

        if targetVisible && !hologramRoot.isEnabled {
            hologramRoot.isEnabled = true
        }

        hologramRoot.components.set(
            OpacityComponent(opacity: visibility)
        )

        let appearScale = 0.82 + (0.18 * visibility)
        hologramRoot.scale = SIMD3<Float>(repeating: appearScale)

        if !targetVisible && visibility <= 0.001 {
            hologramRoot.isEnabled = false
        }

        let pulse = 1.0 + 0.045 * sin(elapsedTime * 2.4)
        glowRoot.scale = SIMD3<Float>(repeating: pulse)
    }

    private func showRandomHologram() {
        let asset = assetLibrary.randomAsset(excluding: currentAssetName)
        currentAssetName = asset.name

        for child in Array(modelSpinRoot.children) {
            child.removeFromParent()
        }

        let bodyModel = asset.source.normalizedForHologram(
            targetMaxDimension: targetModelSize
        )

        // Clone before replacing materials so all three render passes start
        // from the same imported geometry.
        let wireframeModel = bodyModel.clone(recursive: true)
        let ghostModel = bodyModel.clone(recursive: true)

        bodyModel.applyHologramMaterialRecursively(
            materialFactory.makeBodyMaterial(opacity: 0.42)
        )

        wireframeModel.applyHologramMaterialRecursively(
            materialFactory.makeWireframeMaterial(opacity: 0.38)
        )

        // Slightly expand the wireframe so it doesn't z-fight the body.
        wireframeModel.scale = wireframeModel.scale * 1.006

        ghostModel.applyHologramMaterialRecursively(
            materialFactory.makeWireframeMaterial(opacity: 0.12)
        )
        ghostModel.scale = ghostModel.scale * 1.012
        ghostModel.components.set(OpacityComponent(opacity: 0.28))
        ghostModelRoot = ghostModel

        modelSpinRoot.addChild(bodyModel)
        modelSpinRoot.addChild(wireframeModel)
        modelSpinRoot.addChild(ghostModel)

        if visibility < 0.05 {
            visibility = 0
        }

        targetVisible = true
        hologramRoot.isEnabled = true
    }

    private func buildEffects() {
        buildLightRing(
            parent: ringA,
            majorRadius: 0.073,
            intensityBias: 1.0
        )

        buildLightRing(
            parent: ringB,
            majorRadius: 0.086,
            intensityBias: 0.82
        )

        buildScanField()
        buildScanSweep()

        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.071),
            materials: [
                materialFactory.makeLightMaterial(
                    opacity: 0.025,
                    intensity: 0.75,
                    whiteMix: 0.25
                )
            ]
        )

        glowRoot.addChild(glow)
    }

    private func buildLightRing(
        parent: Entity,
        majorRadius: Float,
        intensityBias: Float
    ) {
        // A narrow emissive core plus increasingly soft halo shells. They are
        // meshes technically, but the eye reads the layered emission as light.
        let layers: [
            (minorRadius: Float, opacity: Float, intensity: Float, whiteMix: CGFloat)
        ] = [
            (0.00065, 0.82, 4.20 * intensityBias, 0.88),
            (0.00165, 0.20, 2.10 * intensityBias, 0.70),
            (0.00360, 0.055, 1.00 * intensityBias, 0.35)
        ]

        for layer in layers {
            do {
                let mesh = try TorusMeshFactory.make(
                    majorRadius: majorRadius,
                    minorRadius: layer.minorRadius,
                    majorSegments: 96,
                    minorSegments: 12
                )

                let model = ModelEntity(
                    mesh: mesh,
                    materials: [
                        materialFactory.makeLightMaterial(
                            opacity: layer.opacity,
                            intensity: layer.intensity,
                            whiteMix: layer.whiteMix
                        )
                    ]
                )

                parent.addChild(model)
            } catch {
                print("Unable to build hologram light ring: \(error)")
            }
        }
    }

    private func buildScanField() {
        // Faint horizontal slice-lines throughout the projection volume. These
        // aren't a surface shader, but combined with the wireframe render pass
        // they create the Leia-style scanned-volume read on visionOS.
        let lineCount = 13
        let minY: Float = -0.052
        let maxY: Float = 0.052

        for index in 0..<lineCount {
            let t = Float(index) / Float(max(lineCount - 1, 1))
            let y = minY + (maxY - minY) * t
            let radius = 0.057 + 0.003 * sin(Float(index) * 1.71)

            do {
                let mesh = try TorusMeshFactory.make(
                    majorRadius: radius,
                    minorRadius: 0.00022,
                    majorSegments: 72,
                    minorSegments: 8
                )

                let line = ModelEntity(
                    mesh: mesh,
                    materials: [
                        materialFactory.makeLightMaterial(
                            opacity: index.isMultiple(of: 3) ? 0.10 : 0.045,
                            intensity: index.isMultiple(of: 3) ? 1.7 : 1.1,
                            whiteMix: 0.55
                        )
                    ]
                )

                line.position.y = y
                scanFieldRoot.addChild(line)
            } catch {
                print("Unable to build scan field line: \(error)")
            }
        }
    }

    private func buildScanSweep() {
        do {
            let mesh = try TorusMeshFactory.make(
                majorRadius: 0.061,
                minorRadius: 0.00065,
                majorSegments: 88,
                minorSegments: 10
            )

            let sweep = ModelEntity(
                mesh: mesh,
                materials: [
                    materialFactory.makeLightMaterial(
                        opacity: 0.58,
                        intensity: 3.8,
                        whiteMix: 0.92
                    )
                ]
            )

            scanSweepRoot.addChild(sweep)
        } catch {
            print("Unable to build scan sweep: \(error)")
        }
    }

    private func updateScanSweep() {
        // Move one brighter line continuously through the hologram and wrap.
        let cycle = scanPhase.truncatingRemainder(dividingBy: 1.0)
        scanSweepRoot.position.y = -0.058 + cycle * 0.116

        let pulse = 0.94 + 0.06 * sin(elapsedTime * 16.0)
        scanSweepRoot.scale = SIMD3<Float>(repeating: pulse)
    }

    private func updateGhosting() {
        guard let ghostModelRoot else { return }

        // Sub-millimeter instability. Enough to create a slight RGB/projector
        // ghost impression without making the model visibly shake.
        ghostModelRoot.position.x = sin(elapsedTime * 23.0) * 0.00055
        ghostModelRoot.position.z = cos(elapsedTime * 17.0) * 0.00035

        let ghostOpacity = 0.18 + 0.10 * (0.5 + 0.5 * sin(elapsedTime * 31.0))
        ghostModelRoot.components.set(
            OpacityComponent(opacity: ghostOpacity)
        )
    }

    private func move(
        _ value: Float,
        toward target: Float,
        maxDelta: Float
    ) -> Float {
        let difference = target - value

        if abs(difference) <= maxDelta {
            return target
        }

        return value + (difference > 0 ? maxDelta : -maxDelta)
    }
}
