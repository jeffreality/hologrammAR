import ARKit
import Foundation

/// Intentionally simple classifier for the POC.
///
/// It ignores the thumb and asks whether the four long fingers are extended
/// relative to their knuckles. This is much more tolerant of fist occlusion
/// than requiring every fingertip to report `isTracked == true`.
enum HandPoseClassifier {
    private static let extendedRatioThreshold: Float = 1.45

    static func classify(_ skeleton: HandSkeleton) -> HandPose {
        let wrist = skeleton.position(of: .wrist)

        let fingerPairs: [(tip: HandSkeleton.JointName, knuckle: HandSkeleton.JointName)] = [
            (.indexFingerTip, .indexFingerKnuckle),
            (.middleFingerTip, .middleFingerKnuckle),
            (.ringFingerTip, .ringFingerKnuckle),
            (.littleFingerTip, .littleFingerKnuckle)
        ]

        var extendedCount = 0

        for pair in fingerPairs {
            let tip = skeleton.position(of: pair.tip)
            let knuckle = skeleton.position(of: pair.knuckle)

            let tipDistance = tip.distance(to: wrist)
            let knuckleDistance = max(knuckle.distance(to: wrist), 0.001)
            let ratio = tipDistance / knuckleDistance

            if ratio >= extendedRatioThreshold {
                extendedCount += 1
            }
        }

        if extendedCount >= 3 {
            return .open
        }

        if extendedCount <= 1 {
            return .closed
        }

        return .intermediate
    }
}
