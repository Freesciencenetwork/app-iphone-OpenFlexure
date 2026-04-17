import SwiftUI

struct StageControlCard: View {
    @ObservedObject var model: MicroscopeRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STAGE CONTROL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NeonTheme.cyan)
                Spacer()
                Text("\(model.position.x)  \(model.position.y)  \(model.position.z)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NeonTheme.cyan)
            }

            HStack(alignment: .center, spacing: 20) {
                dPad
                    .frame(maxWidth: .infinity)
                focusColumn
            }
        }
        .neonCard()
    }

    private var disabled: Bool {
        !model.connected || model.busyMoving
    }

    private var dPad: some View {
        let s: CGFloat = 52
        return VStack(spacing: 10) {
            neonArrowButton(systemName: "arrow.up") {
                Task { await model.nudgeUp() }
            }
            .frame(width: s, height: s)
            HStack(spacing: 10) {
                neonArrowButton(systemName: "arrow.left") {
                    Task { await model.nudgeLeft() }
                }
                .frame(width: s, height: s)
                Button {
                    Task { await model.moveStageToOrigin() }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(NeonTheme.cyan.opacity(0.4), lineWidth: 1)
                            .frame(width: s * 0.85, height: s * 0.85)
                        Circle()
                            .fill(NeonTheme.cyan.opacity(0.12))
                            .frame(width: s * 0.5, height: s * 0.5)
                        Image(systemName: "scope")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(NeonTheme.cyan)
                    }
                    .frame(width: s, height: s)
                }
                .buttonStyle(.plain)
                neonArrowButton(systemName: "arrow.right") {
                    Task { await model.nudgeRight() }
                }
                .frame(width: s, height: s)
            }
            neonArrowButton(systemName: "arrow.down") {
                Task { await model.nudgeDown() }
            }
            .frame(width: s, height: s)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var focusColumn: some View {
        VStack(spacing: 8) {
            neonArrowButton(systemName: "plus") {
                Task { await model.focusPlus() }
            }
            .frame(width: 52, height: 52)
            Text("FOCUS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NeonTheme.textMuted)
            neonArrowButton(systemName: "minus") {
                Task { await model.focusMinus() }
            }
            .frame(width: 52, height: 52)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func neonArrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(NeonTheme.cyan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(NeonTheme.cyan.opacity(0.45), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
