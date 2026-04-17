import SwiftUI

struct MainMicroscopeView: View {
    @ObservedObject var model: MicroscopeRuntime

    var body: some View {
        ZStack {
            NeonTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusBar
                        .padding(.horizontal, 4)

                    previewCard

                    StageControlCard(model: model)

                    IlluminationCard(stub: model.illuminationStub)

                    if let err = model.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.12))
                            )
                    }

                    if let status = model.captureWorkflowStatus, !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(NeonTheme.greenConnected.opacity(0.95))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(NeonTheme.greenConnected.opacity(0.12))
                            )
                    }

                    BottomCaptureBar(model: model)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .sheet(isPresented: $model.showSettings) {
            ConnectionSettingsView(model: model)
        }
        .onAppear {
            model.start()
        }
        .onDisappear {
            Task {
                await model.stopPreviewIfRunning()
            }
            model.stop()
        }
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.connected ? NeonTheme.greenConnected : Color.red.opacity(0.85))
                    .frame(width: 10, height: 10)
                    .shadow(color: model.connected ? NeonTheme.greenConnected.opacity(0.6) : .clear, radius: 6)
                Text(model.connected ? "CONNECTED" : "OFFLINE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(model.connected ? NeonTheme.greenConnected : Color.red.opacity(0.9))
            }
            Spacer()
            Text("X:\(model.position.x)  Y:\(model.position.y)  Z:\(model.position.z)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(NeonTheme.cyan)
            Button {
                model.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(NeonTheme.cyan)
                    .shadow(color: NeonTheme.cyan.opacity(0.35), radius: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(NeonTheme.cyan.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: NeonTheme.magenta.opacity(0.2), radius: 20, y: 0)

            if let img = model.previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44))
                        .foregroundStyle(NeonTheme.cyan.opacity(0.5))
                    Text(model.connected ? "Loading preview…" : "Waiting for connection…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NeonTheme.textMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
