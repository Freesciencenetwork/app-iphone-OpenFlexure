import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var model: MicroscopeRuntime
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Microscope") {
                    TextField("Base URL", text: $model.baseURLString)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("Stage steps (relative)") {
                    Stepper("X step: \(model.stepX)", value: $model.stepX, in: 1...5000, step: 1)
                    Stepper("Y step: \(model.stepY)", value: $model.stepY, in: 1...5000, step: 1)
                    Stepper("Z (focus) step: \(model.stepZ)", value: $model.stepZ, in: 1...2000, step: 1)
                }

                Section("HTTP") {
                    Stepper("Timeout: \(model.timeoutSeconds)s", value: $model.timeoutSeconds, in: 5...120, step: 5)
                }

                Section("Camera preview") {
                    Toggle("Start GPU preview after connect", isOn: $model.startGPUPreviewAfterConnect)
                    Text("Window [x,y,w,h] as four integers, comma-separated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0,0,832,624", text: Binding(
                        get: { model.previewWindow.map(String.init).joined(separator: ",") },
                        set: { s in
                            let parts = s.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                            if parts.count == 4 { model.previewWindow = parts }
                        }
                    ))
                    .textInputAutocapitalization(.never)
                }

                Section("Automation") {
                    if model.busyAutomation {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Running microscope automation…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Refresh available actions") {
                        Task {
                            await model.refreshAutomationCapabilities()
                        }
                    }

                    Button("Auto focus") {
                        Task {
                            await model.runAutofocus()
                        }
                    }
                    .disabled(model.busyAutomation)

                    Button("Calibrate camera/stage mapping") {
                        Task {
                            await model.calibrateCameraStageMapping()
                        }
                    }
                    .disabled(model.busyAutomation)

                    if model.automationCapabilities.autoGainExposureActionPath != nil {
                        Button("Auto gain & shutter speed") {
                            Task {
                                await model.runAutoGainExposure()
                            }
                        }
                        .disabled(model.busyAutomation)
                    }

                    if model.automationCapabilities.cameraAutoCalibrationActionPath != nil {
                        Button("Camera auto-calibration") {
                            Task {
                                await model.runCameraAutoCalibration()
                            }
                        }
                        .disabled(model.busyAutomation)
                    }

                    if let status = model.automationStatus, !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Actions are discovered from the microscope API at runtime. Camera auto-calibration should be run with no sample in view; auto gain/shutter can be re-run during normal use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Button("Move stage to origin (0,0,0)") {
                        Task {
                            await model.moveStageToOrigin()
                        }
                    }

                    Button("Define current position as zero") {
                        Task {
                            await model.zeroStage()
                        }
                    }
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("Settings")
            .task {
                await model.refreshAutomationCapabilities()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.applySettingsAndReconnect()
                        dismiss()
                    }
                }
            }
        }
    }
}
