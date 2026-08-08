import simd

extension SIMD3 where Scalar == Float {
    func distance(to other: SIMD3<Float>) -> Float {
        simd_distance(self, other)
    }
}
