import SwiftUI

struct IlluminationCard: View {
    @ObservedObject var stub: StubIlluminationService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ILLUMINATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NeonTheme.cyan)

            HStack {
                Text("\(stub.levelPercent)%")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NeonTheme.textMuted)
                Spacer()
                Toggle("", isOn: $stub.lampOn)
                    .labelsHidden()
                    .tint(NeonTheme.cyan)
            }

            Slider(value: Binding(
                get: { Double(stub.levelPercent) },
                set: { stub.levelPercent = Int($0.rounded()) }
            ), in: 0...100, step: 1)
            .tint(NeonTheme.cyan)

            Text(stub.footnote)
                .font(.caption2)
                .foregroundStyle(NeonTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .neonCard()
    }
}
