import SwiftUI

/// A card: creamDeep on cream, radius 14, no shadow.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.lg
    var background: Color = Theme.Colors.creamDeep
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(background)
            )
    }
}

/// 1pt sand divider at 30% opacity.
struct SandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.sand.opacity(Theme.Metrics.dividerOpacity))
            .frame(height: Theme.Metrics.dividerHeight)
    }
}

/// The cream screen background, applied to every screen.
struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.cream.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

/// The wordmark: PETITE HOME CO. in serif capitals, letterspaced, sand.
/// Used on the Sign in with Apple screen and the PDF cover only.
struct Wordmark: View {
    var body: some View {
        Text("PETITE HOME CO.")
            .font(Typography.wordmark)
            .kerning(Theme.Tracking.wordmark * 20)
            .foregroundStyle(Theme.Colors.sand)
            .accessibilityLabel("Petite Home Co.")
    }
}

/// A chip: full-round, powderBlue fill when selected (ink on top), creamDeep otherwise.
struct Chip: View {
    let label: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(Typography.label)
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Theme.Colors.powderBlue : Theme.Colors.creamDeep)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

/// Avatars. Kids: sand circle with serif initial in cream. Adults: powderBlue circle.
struct AvatarView: View {
    enum Kind { case child, adult }
    let initial: String
    let kind: Kind
    var size: CGFloat = Theme.Metrics.avatarSize

    var body: some View {
        ZStack {
            Circle().fill(kind == .child ? Theme.Colors.sand : Theme.Colors.powderBlue)
            Text(initial.prefix(1).uppercased())
                .font(Typography.serif(size * 0.45))
                .foregroundStyle(kind == .child ? Theme.Colors.cream : Theme.Colors.ink)
        }
        .frame(width: size, height: size)
    }
}

/// The premium lock. Always this phrase, never a padlock on its own.
struct PremiumPill: View {
    var body: some View {
        Text("Premium keeps this for you")
            .font(Typography.capsLabel)
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.Colors.powderBlue))
    }
}

/// An SF Symbol at the brand weight, sandDeep by default, powderBlueDk when active.
struct BrandIcon: View {
    let systemName: String
    var isActive: Bool = false
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(isActive ? Theme.Colors.powderBlueDk : Theme.Colors.sandDeep)
    }
}

/// Completeness ring: powderBlueDk stroke on creamDeep track, serif number in the center.
struct CompletenessRing: View {
    let percent: Int
    var size: CGFloat = 140
    var lineWidth: CGFloat = Theme.Metrics.ringLineWidth

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.creamDeep, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0), 100)) / 100)
                .stroke(percent >= 100 ? Theme.Colors.success : Theme.Colors.powderBlueDk,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: percent)
            VStack(spacing: 0) {
                Text("\(percent)")
                    .font(Typography.ringNumber(size * 0.32))
                    .foregroundStyle(Theme.Colors.ink)
                Text("percent")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Colors.sandDeep)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Family File \(percent) percent complete")
    }
}

/// Thin progress bar for onboarding.
struct ProgressBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.creamDeep)
                Capsule().fill(Theme.Colors.powderBlueDk)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeOut(duration: 0.35), value: progress)
            }
        }
        .frame(height: 4)
    }
}

/// Empty states say what to do, not what is missing.
struct EmptyStateRow: View {
    let instruction: String
    var systemImage: String = "plus.circle"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                BrandIcon(systemName: systemImage, isActive: true)
                Text(instruction)
                    .font(Typography.body)
                    .foregroundStyle(Theme.Colors.ink)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.sandDeep)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
