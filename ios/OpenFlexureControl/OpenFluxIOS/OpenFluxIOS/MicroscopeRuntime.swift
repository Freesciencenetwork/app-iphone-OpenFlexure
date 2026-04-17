import Combine
import Foundation
import UIKit

@MainActor
final class MicroscopeRuntime: ObservableObject {
    @Published var baseURLString: String = "http://microscope.local:5000"
    @Published var stepX: Int = 50
    @Published var stepY: Int = 50
    @Published var stepZ: Int = 10
    @Published var timeoutSeconds: Int = 15
    /// When true, `start()` attempts GPU preview start once after a successful ping.
    @Published var startGPUPreviewAfterConnect: Bool = false
    @Published var previewWindow: [Int] = [0, 0, 832, 624]

    @Published var connected: Bool = false
    @Published var position: StagePosition = StagePosition(x: 0, y: 0, z: 0)
    @Published var previewImage: UIImage?
    @Published var busyMoving: Bool = false
    @Published var busyCapturing: Bool = false
    @Published var busyCaptureWorkflow: Bool = false
    @Published var busyAutomation: Bool = false
    @Published var lastError: String?
    @Published var captureWorkflowStatus: String?
    @Published var automationStatus: String?
    @Published var showSettings: Bool = false
    @Published var automationCapabilities = MicroscopeAutomationCapabilities()

    /// UI-only until a device-specific lamp API is wired.
    let illuminationStub = StubIlluminationService()

    private var heartbeatTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var didStartPreviewForSession: Bool = false

    /// Call after changing connection-related settings so preview can run again if enabled.
    func applySettingsAndReconnect() {
        automationCapabilities = MicroscopeAutomationCapabilities()
        start()
    }

    func start() {
        stop()
        didStartPreviewForSession = false
        heartbeatTask = Task { await self.heartbeatLoop() }
        snapshotTask = Task { await self.snapshotLoop() }
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        snapshotTask?.cancel()
        snapshotTask = nil
    }

    private func client() throws -> OpenFlexureClient {
        let s = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: s), let scheme = u.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw OpenFlexureClientError.invalidBaseURL
        }
        return OpenFlexureClient(baseURL: u, timeoutSeconds: TimeInterval(timeoutSeconds))
    }

    private func heartbeatLoop() async {
        while !Task.isCancelled {
            do {
                let c = try client()
                try await c.ping()
                connected = true
                let p = try await c.getStagePosition()
                position = p
                lastError = nil

                if startGPUPreviewAfterConnect, !didStartPreviewForSession {
                    didStartPreviewForSession = true
                    do {
                        try await c.startGPUPreview(window: previewWindow)
                    } catch {
                        lastError = "Preview: \(error.localizedDescription)"
                    }
                }
            } catch {
                connected = false
                lastError = error.localizedDescription
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func snapshotLoop() async {
        while !Task.isCancelled {
            if connected {
                do {
                    let c = try client()
                    let data = try await c.fetchSnapshotJPEG()
                    if let img = UIImage(data: data) {
                        previewImage = img
                    }
                } catch {
                    // keep last good frame
                }
            }
            try? await Task.sleep(for: .milliseconds(140))
        }
    }

    func move(dx: Int, dy: Int, dz: Int) async {
        guard dx != 0 || dy != 0 || dz != 0 else { return }
        busyMoving = true
        lastError = nil
        defer { busyMoving = false }
        do {
            let c = try client()
            try await c.moveStage(StageMoveRequest(x: dx, y: dy, z: dz))
            position = try await c.getStagePosition()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func nudgeLeft() async { await move(dx: -stepX, dy: 0, dz: 0) }
    func nudgeRight() async { await move(dx: stepX, dy: 0, dz: 0) }
    func nudgeUp() async { await move(dx: 0, dy: stepY, dz: 0) }
    func nudgeDown() async { await move(dx: 0, dy: -stepY, dz: 0) }
    func focusPlus() async { await move(dx: 0, dy: 0, dz: stepZ) }
    func focusMinus() async { await move(dx: 0, dy: 0, dz: -stepZ) }

    func capturePhoto() async {
        await captureImage(plan: ImageCapturePlan(filename: defaultCaptureStem(prefix: "ios_capture")))
    }

    func zeroStage() async {
        busyMoving = true
        lastError = nil
        defer { busyMoving = false }
        do {
            let c = try client()
            try await c.zeroStage()
            position = try await c.getStagePosition()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func moveStageToOrigin() async {
        busyMoving = true
        lastError = nil
        defer { busyMoving = false }
        do {
            let c = try client()
            try await c.moveStage(StageMoveRequest(x: 0, y: 0, z: 0, absolute: true))
            position = try await c.getStagePosition()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func captureImage(plan: ImageCapturePlan) async {
        busyCaptureWorkflow = true
        busyCapturing = true
        lastError = nil
        captureWorkflowStatus = nil
        defer {
            busyCapturing = false
            busyCaptureWorkflow = false
        }

        do {
            let c = try client()
            try await c.capture(filename: plan.filename)
            captureWorkflowStatus = "Image captured as \(plan.filename)."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func recordVideo(plan: VideoCapturePlan) async {
        busyCaptureWorkflow = true
        lastError = nil
        captureWorkflowStatus = "Recording \(plan.durationSeconds)s of video…"
        defer { busyCaptureWorkflow = false }

        do {
            let c = try client()
            let outputURL = try await SnapshotVideoRecorder.record(plan: plan) {
                try await c.fetchSnapshotJPEG()
            }
            captureWorkflowStatus = "Video saved as \(outputURL.lastPathComponent)."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runMosaic(plan: MosaicCapturePlan) async {
        busyCaptureWorkflow = true
        busyMoving = true
        busyCapturing = true
        lastError = nil
        captureWorkflowStatus = nil
        defer {
            busyCapturing = false
            busyMoving = false
            busyCaptureWorkflow = false
        }

        do {
            let c = try client()
            let startPosition = position

            var autofocusHref: String?
            if plan.autofocusEachTile {
                let capabilities = try await c.discoverAutomationCapabilities()
                automationCapabilities = capabilities
                guard let href = capabilities.autofocusActionPath else {
                    throw OpenFlexureClientError.unsupportedCapability("Autofocus for mosaic")
                }
                autofocusHref = href
            }

            var capturedTiles = 0
            for row in 0..<plan.rows {
                let stepDirection = row.isMultiple(of: 2) ? 1 : -1

                for column in 0..<plan.columns {
                    captureWorkflowStatus = "Capturing tile \(capturedTiles + 1) of \(plan.tileCount)…"

                    if let autofocusHref {
                        try await c.invokeDiscoveredAction(href: autofocusHref)
                    }

                    let tileName = "\(plan.filenamePrefix)_r\(row + 1)_c\(column + 1)"
                    try await c.capture(filename: tileName)
                    capturedTiles += 1

                    if column < plan.columns - 1 {
                        try await c.moveStage(
                            StageMoveRequest(x: stepDirection * plan.stepX, y: 0, z: 0)
                        )
                    }
                }

                if row < plan.rows - 1 {
                    try await c.moveStage(StageMoveRequest(x: 0, y: plan.stepY, z: 0))
                }
            }

            if plan.returnToStart {
                try await c.moveStage(
                    StageMoveRequest(
                        x: startPosition.x,
                        y: startPosition.y,
                        z: startPosition.z,
                        absolute: true
                    )
                )
            }

            position = try await c.getStagePosition()
            captureWorkflowStatus = "Mosaic capture complete: \(capturedTiles) tiles."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func defaultCaptureStem(prefix: String) -> String {
        "\(prefix)_\(Int(Date().timeIntervalSince1970))"
    }

    @discardableResult
    func refreshAutomationCapabilities() async -> MicroscopeAutomationCapabilities {
        do {
            let c = try client()
            let capabilities = try await c.discoverAutomationCapabilities()
            automationCapabilities = capabilities
            return capabilities
        } catch {
            automationCapabilities = MicroscopeAutomationCapabilities()
            lastError = error.localizedDescription
            return automationCapabilities
        }
    }

    private func runAutomation(
        named label: String,
        path: KeyPath<MicroscopeAutomationCapabilities, String?>
    ) async {
        busyAutomation = true
        lastError = nil
        automationStatus = nil
        defer { busyAutomation = false }

        do {
            let c = try client()
            let capabilities = try await c.discoverAutomationCapabilities()
            automationCapabilities = capabilities

            guard let href = capabilities[keyPath: path] else {
                throw OpenFlexureClientError.unsupportedCapability(label)
            }

            try await c.invokeDiscoveredAction(href: href)
            if let updatedPosition = try? await c.getStagePosition() {
                position = updatedPosition
            }
            automationStatus = "\(label) completed."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runAutofocus() async {
        await runAutomation(named: "Autofocus", path: \.autofocusActionPath)
    }

    func calibrateCameraStageMapping() async {
        await runAutomation(
            named: "Camera/stage calibration",
            path: \.cameraStageCalibrationActionPath
        )
    }

    func runAutoGainExposure() async {
        await runAutomation(
            named: "Auto gain & shutter",
            path: \.autoGainExposureActionPath
        )
    }

    func runCameraAutoCalibration() async {
        await runAutomation(
            named: "Camera auto-calibration",
            path: \.cameraAutoCalibrationActionPath
        )
    }

    func stopPreviewIfRunning() async {
        do {
            let c = try client()
            try await c.stopGPUPreview()
        } catch {
            // ignore
        }
    }
}
