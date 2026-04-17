import SwiftUI

/// Neon / cyberpunk microscope UI tokens (match design reference).
enum NeonTheme {
    static let backgroundTop = Color(red: 0.12, green: 0.06, blue: 0.22)
    static let backgroundBottom = Color(red: 0.04, green: 0.02, blue: 0.10)
    static let cardFill = Color(red: 0.10, green: 0.05, blue: 0.18).opacity(0.92)
    static let cyan = Color(red: 0.25, green: 0.95, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.2, blue: 0.65)
    static let greenConnected = Color(red: 0.2, green: 1.0, blue: 0.45)
    static let textMuted = Color.white.opacity(0.65)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var cyanGlowGradient: LinearGradient {
        LinearGradient(colors: [cyan.opacity(0.35), cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom)
    }
}

struct NeonCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NeonTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(NeonTheme.cyan.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: NeonTheme.cyan.opacity(0.15), radius: 12, y: 4)
            )
    }
}

extension View {
    func neonCard() -> some View {
        modifier(NeonCardModifier())
    }
}
