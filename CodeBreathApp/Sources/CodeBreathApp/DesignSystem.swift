// Central design tokens and shared UI primitives.

import SwiftUI

enum DS {
    enum Radius {
        static let lg: CGFloat = 16
        static let md: CGFloat = 12
        static let sm: CGFloat = 8
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Font {
        static let titleLg = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title   = SwiftUI.Font.system(size: 17, weight: .bold)
        static let body    = SwiftUI.Font.system(size: 13)
        static let caption = SwiftUI.Font.system(size: 11)
    }

    static func categoryColor(_ c: TipCategory) -> Color {
        switch c {
        case .eye:       return .blue
        case .neck:      return .purple
        case .combo:     return Color(red: 0.45, green: 0.35, blue: 0.85) // violet, distinct from eye-blue/neck-purple
        case .sedentary: return .green
        case .noon:      return .orange
        }
    }
}

// MARK: - Pressable button style

struct PressableButtonStyle<Background: View>: ButtonStyle {
    var background: Background
    var tint: Color = .primary
    var cornerRadius: CGFloat = DS.Radius.sm

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(tint)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
