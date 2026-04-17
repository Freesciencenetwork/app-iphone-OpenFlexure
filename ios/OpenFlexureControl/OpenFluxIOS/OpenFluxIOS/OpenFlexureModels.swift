import Foundation

nonisolated enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
    case image
    case video
    case mosaic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image: return "Image"
        case .video: return "Video"
        case .mosaic: return "Mosaic"
        }
    }
}

nonisolated struct ImageCapturePlan: Sendable, Equatable {
    var filename: String
}

nonisolated struct VideoCapturePlan: Sendable, Equatable {
    var filename: String
    var durationSeconds: Int
    var framesPerSecond: Int
}

nonisolated struct MosaicCapturePlan: Sendable, Equatable {
    var filenamePrefix: String
    var rows: Int
    var columns: Int
    var stepX: Int
    var stepY: Int
    var autofocusEachTile: Bool
    var returnToStart: Bool

    var tileCount: Int {
        rows * columns
    }
}

nonisolated struct StagePosition: Codable, Equatable, Sendable {
    var x: Int
    var y: Int
    var z: Int
}

nonisolated struct StageMoveRequest: Encodable, Sendable {
    var x: Int?
    var y: Int?
    var z: Int?
    var absolute: Bool?

    init(x: Int? = nil, y: Int? = nil, z: Int? = nil, absolute: Bool? = nil) {
        self.x = x
        self.y = y
        self.z = z
        self.absolute = absolute
    }
}

nonisolated struct CaptureRequest: Encodable, Sendable {
    var filename: String
}

nonisolated struct PreviewStartRequest: Encodable, Sendable {
    var window: [Int]
}

/// Minimal action envelope from OpenFlexure v2 API.
nonisolated struct OpenFlexureAction: Decodable, Sendable {
    var id: String?
    var status: String?
    var action: String?
}

nonisolated struct OpenFlexureErrorResponse: Decodable, Sendable {
    var message: String?
    var name: String?
}

nonisolated struct MicroscopeAutomationCapabilities: Sendable, Equatable {
    var autofocusActionPath: String?
    var cameraStageCalibrationActionPath: String?
    var autoGainExposureActionPath: String?
    var cameraAutoCalibrationActionPath: String?

    var hasAny: Bool {
        autofocusActionPath != nil ||
        cameraStageCalibrationActionPath != nil ||
        autoGainExposureActionPath != nil ||
        cameraAutoCalibrationActionPath != nil
    }
}

nonisolated enum OpenFlexureClientError: LocalizedError, Sendable {
    case invalidBaseURL
    case badStatus(Int)
    case noActionId
    case actionFailed(String, String)
    case actionTimeout(String)
    case notJPEG
    case unsupportedCapability(String)
    case videoWriterFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL: return "Invalid microscope base URL."
        case .badStatus(let c): return "HTTP error (\(c))."
        case .noActionId: return "Server did not return an action id."
        case .actionFailed(let id, let body): return "Action \(id) failed: \(body)"
        case .actionTimeout(let id): return "Action \(id) timed out."
        case .notJPEG: return "Snapshot was not valid JPEG data."
        case .unsupportedCapability(let capability): return "\(capability) is not exposed by this microscope API."
        case .videoWriterFailed(let message): return "Video recording failed: \(message)"
        }
    }
}
