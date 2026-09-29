import SwiftUI

/// Primary: powderBlueDk fill, white text, 52pt tall, full width, sentence case.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.white)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Colors.powderBlueDk)
                    .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            )
            .contentShape(Rectangle())
    }
}

/// Secondary / skip: no fill, sandDeep text.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.sandDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Outline button on cream: ink text, 1pt rule border.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.Colors.sand, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(enabled: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(isEnabled: enabled) }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}
