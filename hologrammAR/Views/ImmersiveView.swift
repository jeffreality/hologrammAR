import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    @State private var controller = HologramSceneController()

    var body: some View {
        RealityView { content in
            await controller.prepare()
            content.add(controller.anchor)

            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                controller.update(deltaTime: event.deltaTime)
            }
        }
        .upperLimbVisibility(.automatic)
        .task {
            appModel.handTracking.start()
        }
        .onChange(of: appModel.handTracking.pose) { _, pose in
            controller.handle(pose)
        }
        .onDisappear {
            appModel.handTracking.stop()
            appModel.immersiveSpaceState = .closed
        }
    }
}
