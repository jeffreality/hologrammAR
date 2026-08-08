import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 54))
                .symbolRenderingMode(.hierarchical)

            Text("hologrammAR")
                .font(.largeTitle.bold())

            Text("Open your left hand to summon a hologram. Close your fist to dismiss it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)

            StatusBadge(
                title: statusTitle,
                systemImage: statusIcon
            )

            Button(buttonTitle) {
                Task {
                    await toggleImmersiveSpace()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appModel.immersiveSpaceState == .transitioning)

            if let errorMessage = appModel.handTracking.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(36)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var buttonTitle: String {
        switch appModel.immersiveSpaceState {
        case .closed:
            "Enter Hologram Mode"
        case .transitioning:
            "Opening…"
        case .open:
            "Exit Hologram Mode"
        }
    }

    private var statusTitle: String {
        switch appModel.immersiveSpaceState {
        case .closed:
            "Ready"
        case .transitioning:
            "Starting"
        case .open:
            appModel.handTracking.isRunning
                ? "Tracking left hand"
                : "Waiting for hand tracking"
        }
    }

    private var statusIcon: String {
        switch appModel.immersiveSpaceState {
        case .closed:
            "circle"
        case .transitioning:
            "hourglass"
        case .open:
            appModel.handTracking.isRunning
                ? "hand.raised"
                : "hand.raised.slash"
        }
    }

    private func toggleImmersiveSpace() async {
        switch appModel.immersiveSpaceState {
        case .closed:
            appModel.immersiveSpaceState = .transitioning

            let result = await openImmersiveSpace(
                id: AppModel.immersiveSpaceID
            )

            switch result {
            case .opened:
                appModel.immersiveSpaceState = .open

            case .userCancelled, .error:
                appModel.immersiveSpaceState = .closed

            @unknown default:
                appModel.immersiveSpaceState = .closed
            }

        case .open:
            appModel.immersiveSpaceState = .transitioning
            await dismissImmersiveSpace()
            appModel.immersiveSpaceState = .closed

        case .transitioning:
            break
        }
    }
}
