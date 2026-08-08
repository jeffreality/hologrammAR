import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    static let immersiveSpaceID = "HologramImmersiveSpace"

    enum ImmersiveSpaceState {
        case closed
        case transitioning
        case open
    }

    var immersiveSpaceState: ImmersiveSpaceState = .closed
    let handTracking = HandTrackingService()
}
