import SwiftUI

/// Primary: powderBlueDk, ink text, 52pt tall, full width, sentence case.
/// On iOS 26 the fill is tinted interactive glass; before that a flat fill.
/// Presses scale to 0.98; the disabled state fades in and out.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .glassFill(Theme.Colors.powderBlueDk,
                       in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous),
                       fallback: Theme.Colors.powderBlueDk)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: isEnabled)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Secondary / skip: sandDeep text. Before iOS 26 it is underlined the way Seek
/// Faith's skip links are; on iOS 26 it floats on clear glass, since the action
/// bar sits over scrolling content there.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout)
            .underline(!Glass26.available)
            .foregroundStyle(Theme.Colors.sandDeep)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassFill(nil, in: Capsule(), fallback: .clear)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Outline button on cream: ink text, 1pt sand border.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .glassFill(nil, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous), fallback: .clear)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.Colors.sand, lineWidth: Glass26.available ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// A primary button on the dark moment screen: powder blue text, blue outline.
struct MomentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.button)
            .foregroundStyle(Theme.Colors.Fixed.powderBlue)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.Colors.Fixed.powderBlue.opacity(0.5), lineWidth: 1.5)
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
extension ButtonStyle where Self == MomentButtonStyle {
    static var moment: MomentButtonStyle { MomentButtonStyle() }
}
