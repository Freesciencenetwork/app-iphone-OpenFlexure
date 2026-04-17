import SwiftUI

struct ContentView: View {
    @StateObject private var model = MicroscopeRuntime()

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.03, blue: 0.14),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            MainMicroscopeView(model: model)

            if !model.connected, model.previewImage == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPENFLUX")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("Microscope remote")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.52, green: 0.95, blue: 1.0))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .allowsHitTesting(false)
            }
        }
    }
}
