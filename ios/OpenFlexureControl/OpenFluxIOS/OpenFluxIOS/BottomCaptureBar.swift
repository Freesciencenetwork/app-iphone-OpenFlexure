import SwiftUI

struct BottomCaptureBar: View {
    @ObservedObject var model: MicroscopeRuntime
    @State private var showPlanner = false
    @State private var plannerMode: CaptureMode = .image

    var body: some View {
        HStack(spacing: 0) {
            shutter
            Spacer(minLength: 8)
            modeButton(title: "VIDEO", systemName: "film", mode: .video)
            Spacer(minLength: 8)
            modeButton(title: "MOSAIC", systemName: "square.grid.2x2", mode: .mosaic)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .sheet(isPresented: $showPlanner) {
            CapturePlannerSheet(model: model, preferredMode: plannerMode)
        }
    }

    private var shutter: some View {
        VStack(spacing: 6) {
            Button {
                plannerMode = .image
                showPlanner = true
            } label: {
                ZStack {
                    Circle()
                        .fill(NeonTheme.magenta)
                        .frame(width: 72, height: 72)
                        .shadow(color: NeonTheme.magenta.opacity(0.45), radius: 14, y: 2)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.connected || model.busyCaptureWorkflow)
            .opacity((!model.connected || model.busyCaptureWorkflow) ? 0.45 : 1)

            Text("IMAGE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NeonTheme.textMuted)
        }
    }

    private func modeButton(title: String, systemName: String, mode: CaptureMode) -> some View {
        VStack(spacing: 6) {
            Button {
                plannerMode = mode
                showPlanner = true
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 22))
                    .foregroundStyle(NeonTheme.textMuted)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.connected || model.busyCaptureWorkflow)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NeonTheme.textMuted)
            Text("Plan")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(NeonTheme.magenta.opacity(0.85))
        }
        .opacity((!model.connected || model.busyCaptureWorkflow) ? 0.45 : 0.85)
    }
}
