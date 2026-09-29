import SwiftUI

/// The app's motion vocabulary. Ported from Seek Faith's onboarding and prayer
/// flows: slow crossfades between screens, staggered fade-ups within a screen,
/// springs for selection and confirmation, and numeric transitions on numbers.
enum Motion {
    /// Screen-to-screen crossfade in onboarding.
    static let crossfade = Animation.easeInOut(duration: 0.6)
    /// A block of content fading up into place.
    static let reveal = Animation.easeOut(duration: 0.8)
    /// Gap between staggered blocks on one screen.
    static let stagger: Double = 0.35
    /// Chip and plan selection.
    static let select = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// A result settling into view (the ring, a saved state).
    static let settle = Animation.spring(duration: 0.5, bounce: 0.15)
    /// A confirmation pop (task done, code redeemed).
    static let pop = Animation.spring(duration: 0.4, bounce: 0.2)
    /// Brand mark entrance on the moment screen.
    static let entrance = Animation.spring(response: 0.9, dampingFraction: 0.7)
}

/// Fades a block up into place after `index * Motion.stagger` seconds. Respects Reduce Motion.
struct StaggerReveal: ViewModifier {
    let index: Int
    var baseDelay: Double = 0.15
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(Motion.reveal.delay(baseDelay + Double(index) * Motion.stagger)) { shown = true }
                }
            }
    }
}

extension View {
    /// Staggered fade-up. Give siblings ascending indices.
    func reveal(_ index: Int, baseDelay: Double = 0.15) -> some View {
        modifier(StaggerReveal(index: index, baseDelay: baseDelay))
    }
}

/// The hook: lines appear one at a time, then the caller shows the rest.
struct RevealLines: View {
    let lines: [String]
    var cadence: Double = 1.1
    var font: Font = Typography.hook
    var onFinished: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                Text(line)
                    .font(font)
                    .lineSpacing(7)
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(i < shown ? 1 : 0)
                    .offset(y: i < shown || reduceMotion ? 0 : 6)
            }
        }
        .onAppear {
            if reduceMotion {
                shown = lines.count
                onFinished?()
                return
            }
            for i in 1...lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * cadence) {
                    withAnimation(.easeIn(duration: 0.8)) { shown = i }
                    if i == lines.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onFinished?() }
                    }
                }
            }
        }
    }
}

/// Three dots breathing in sequence, for anything that takes a moment.
struct PulsingDots: View {
    var color: Color = Theme.Colors.powderBlueDk
    @State private var on = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(color).frame(width: 8, height: 8)
                    .scaleEffect(on ? 1 : 0.4)
                    .opacity(on ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: on)
            }
        }
        .onAppear { on = true }
        .accessibilityLabel("Working")
    }
}

/// A short eyebrow above a headline: 11pt, tracked, uppercase, accent.
struct Eyebrow: View {
    let text: String
    var color: Color = Theme.Colors.powderBlueDk
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// A rule with a single sand dot in the middle, between Home sections.
struct BrandDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            SandDivider()
            Circle().fill(Theme.Colors.sand).frame(width: 4, height: 4)
            SandDivider()
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityHidden(true)
    }
}

/// The dark "moment" screen: ink ground, cream serif, used once after
/// onboarding. The site's footer is the same warm charcoal, so it stays on brand.
struct MomentScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            Theme.Colors.ink.ignoresSafeArea()
            content()
        }
    }
}
