import ARKit
import Foundation
import Observation

@MainActor
@Observable
final class HandTrackingService {
    private var session: ARKitSession?
    private var provider: HandTrackingProvider?
    private var trackingTask: Task<Void, Never>?

    // Simple temporal stabilization. We don't want one noisy sample
    // to make the hologram flash on or off.
    private var candidatePose: HandPose = .unknown
    private var candidateSampleCount = 0

    private let samplesRequiredForOpen = 5
    private let samplesRequiredForClosed = 3

    private(set) var pose: HandPose = .unknown
    private(set) var isRunning = false
    private(set) var errorMessage: String?

    func start() {
        guard trackingTask == nil else { return }

        guard HandTrackingProvider.isSupported else {
            errorMessage = "Detailed hand tracking isn't supported in this environment. Use a physical Apple Vision Pro."
            return
        }

        errorMessage = nil
        candidatePose = .unknown
        candidateSampleCount = 0
        pose = .unknown

        // A stopped ARKit data provider isn't intended to be restarted.
        // Create a fresh session/provider every time the immersive space opens.
        let newSession = ARKitSession()
        let newProvider = HandTrackingProvider()

        session = newSession
        provider = newProvider

        trackingTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await newSession.run([newProvider])
                isRunning = true

                for await update in newProvider.anchorUpdates {
                    if Task.isCancelled { break }

                    let anchor = update.anchor

                    guard anchor.chirality == .left,
                          anchor.isTracked,
                          let skeleton = anchor.handSkeleton else {
                        continue
                    }

                    let classifiedPose = HandPoseClassifier.classify(skeleton)
                    stabilize(classifiedPose)
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }

            isRunning = false
        }
    }

    func stop() {
        trackingTask?.cancel()
        trackingTask = nil

        session?.stop()
        session = nil
        provider = nil

        candidatePose = .unknown
        candidateSampleCount = 0
        pose = .unknown
        isRunning = false
    }

    private func stabilize(_ newPose: HandPose) {
        // "Intermediate" should not immediately erase a known state.
        // It is our hysteresis/dead-zone state.
        guard newPose != .intermediate else {
            candidatePose = .intermediate
            candidateSampleCount = 0
            return
        }

        if newPose == candidatePose {
            candidateSampleCount += 1
        } else {
            candidatePose = newPose
            candidateSampleCount = 1
        }

        switch newPose {
        case .open:
            if candidateSampleCount >= samplesRequiredForOpen {
                pose = .open
            }

        case .closed:
            if candidateSampleCount >= samplesRequiredForClosed {
                pose = .closed
            }

        case .unknown:
            if candidateSampleCount >= samplesRequiredForClosed {
                pose = .unknown
            }

        case .intermediate:
            break
        }
    }
}
