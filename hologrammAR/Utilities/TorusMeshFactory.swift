import Foundation
import RealityKit
import simd

enum TorusMeshFactory {
    /// Generates a torus centered at the origin, around the local Y axis.
    static func make(
        majorRadius: Float,
        minorRadius: Float,
        majorSegments: Int = 64,
        minorSegments: Int = 10
    ) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity(majorSegments * minorSegments)
        indices.reserveCapacity(majorSegments * minorSegments * 6)

        for majorIndex in 0..<majorSegments {
            let u = Float(majorIndex) / Float(majorSegments) * 2.0 * .pi

            for minorIndex in 0..<minorSegments {
                let v = Float(minorIndex) / Float(minorSegments) * 2.0 * .pi

                let ringRadius = majorRadius + minorRadius * cos(v)

                let x = ringRadius * cos(u)
                let y = minorRadius * sin(v)
                let z = ringRadius * sin(u)

                positions.append(SIMD3<Float>(x, y, z))
            }
        }

        func vertexIndex(_ major: Int, _ minor: Int) -> UInt32 {
            let wrappedMajor = major % majorSegments
            let wrappedMinor = minor % minorSegments
            return UInt32(wrappedMajor * minorSegments + wrappedMinor)
        }

        for majorIndex in 0..<majorSegments {
            for minorIndex in 0..<minorSegments {
                let a = vertexIndex(majorIndex, minorIndex)
                let b = vertexIndex(majorIndex + 1, minorIndex)
                let c = vertexIndex(majorIndex + 1, minorIndex + 1)
                let d = vertexIndex(majorIndex, minorIndex + 1)

                indices.append(contentsOf: [
                    a, b, c,
                    a, c, d
                ])
            }
        }

        var descriptor = MeshDescriptor(name: "HologramTorus")
        descriptor.positions = .init(positions)
        descriptor.primitives = .triangles(indices)

        return try MeshResource.generate(from: [descriptor])
    }
}
