import SwiftUI

struct CapturePlannerSheet: View {
    @ObservedObject var model: MicroscopeRuntime
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: CaptureMode
    @State private var imageFilename: String
    @State private var videoFilename: String
    @State private var videoDurationSeconds: Int
    @State private var videoFramesPerSecond: Int
    @State private var mosaicFilenamePrefix: String
    @State private var mosaicRows: Int
    @State private var mosaicColumns: Int
    @State private var mosaicStepX: Int
    @State private var mosaicStepY: Int
    @State private var mosaicAutofocusEachTile: Bool
    @State private var mosaicReturnToStart: Bool

    init(model: MicroscopeRuntime, preferredMode: CaptureMode) {
        self.model = model
        _selectedMode = State(initialValue: preferredMode)
        _imageFilename = State(initialValue: model.defaultCaptureStem(prefix: "ios_capture"))
        _videoFilename = State(initialValue: model.defaultCaptureStem(prefix: "ios_video"))
        _videoDurationSeconds = State(initialValue: 8)
        _videoFramesPerSecond = State(initialValue: 5)
        _mosaicFilenamePrefix = State(initialValue: model.defaultCaptureStem(prefix: "ios_mosaic"))
        _mosaicRows = State(initialValue: 2)
        _mosaicColumns = State(initialValue: 3)
        _mosaicStepX = State(initialValue: max(model.stepX, 50))
        _mosaicStepY = State(initialValue: max(model.stepY, 50))
        _mosaicAutofocusEachTile = State(initialValue: false)
        _mosaicReturnToStart = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch selectedMode {
                case .image:
                    imagePlanner
                case .video:
                    videoPlanner
                case .mosaic:
                    mosaicPlanner
                }

                if let status = model.captureWorkflowStatus, !status.isEmpty {
                    Section("Last run") {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Capture Planner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var imagePlanner: some View {
        Section("Image capture") {
            TextField("Filename", text: $imageFilename)
                .textInputAutocapitalization(.never)

            Text("One still image captured through the microscope capture action.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Capture image") {
                Task {
                    await model.captureImage(plan: ImageCapturePlan(filename: imageFilename))
                }
            }
            .disabled(!model.connected || model.busyCaptureWorkflow)
        }
    }

    private var videoPlanner: some View {
        Section("Video capture") {
            TextField("Filename", text: $videoFilename)
                .textInputAutocapitalization(.never)

            Stepper("Duration: \(videoDurationSeconds)s", value: $videoDurationSeconds, in: 1...120, step: 1)
            Stepper("Frame rate: \(videoFramesPerSecond) fps", value: $videoFramesPerSecond, in: 1...12, step: 1)

            Text("Records the live snapshot stream into an MP4 file inside the app documents folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Record video") {
                Task {
                    await model.recordVideo(
                        plan: VideoCapturePlan(
                            filename: videoFilename,
                            durationSeconds: videoDurationSeconds,
                            framesPerSecond: videoFramesPerSecond
                        )
                    )
                }
            }
            .disabled(!model.connected || model.busyCaptureWorkflow)
        }
    }

    private var mosaicPlanner: some View {
        Section("Mosaic scan") {
            TextField("Filename prefix", text: $mosaicFilenamePrefix)
                .textInputAutocapitalization(.never)

            Stepper("Rows: \(mosaicRows)", value: $mosaicRows, in: 1...10, step: 1)
            Stepper("Columns: \(mosaicColumns)", value: $mosaicColumns, in: 1...10, step: 1)
            Stepper("Step X: \(mosaicStepX)", value: $mosaicStepX, in: 1...5000, step: 1)
            Stepper("Step Y: \(mosaicStepY)", value: $mosaicStepY, in: 1...5000, step: 1)
            Toggle("Autofocus each tile", isOn: $mosaicAutofocusEachTile)
            Toggle("Return to start when done", isOn: $mosaicReturnToStart)

            Text("This captures a planned grid of \(mosaicRows * mosaicColumns) stills. Stitching is not wired yet; this produces the tile set.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Run mosaic scan") {
                Task {
                    await model.runMosaic(
                        plan: MosaicCapturePlan(
                            filenamePrefix: mosaicFilenamePrefix,
                            rows: mosaicRows,
                            columns: mosaicColumns,
                            stepX: mosaicStepX,
                            stepY: mosaicStepY,
                            autofocusEachTile: mosaicAutofocusEachTile,
                            returnToStart: mosaicReturnToStart
                        )
                    )
                }
            }
            .disabled(!model.connected || model.busyCaptureWorkflow)
        }
    }
}
