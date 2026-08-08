import ARKit
import simd

extension HandSkeleton {
    func position(of jointName: HandSkeleton.JointName) -> SIMD3<Float> {
        let transform = joint(jointName).anchorFromJointTransform
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
}
