import SwiftUI

/// iOS 26 Liquid Glass. Every helper here is a no-op on iOS 17 and 18, where
/// the flat brand look stays exactly as it was, so views call these without
/// branching on the OS themselves.
///
/// What glass is used for, following Apple's guidance: controls that float
/// above content (the onboarding action bar, buttons, chips) and the system
/// bars, never content itself. Cards, lists and text stay on the cream ground.
enum Glass26 {
    static var available: Bool {
        if #available(iOS 26, *) { return true } else { return false }
    }
}

extension View {
    /// Interactive glass behind a control, tinted when `tint` is given.
    /// Before iOS 26 the control gets the flat `fallback` fill instead.
    @ViewBuilder
    func glassFill<S: Shape>(_ tint: Color?, in shape: S, fallback: Color) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self.background(shape.fill(fallback))
        }
    }

    /// The soft fade where scrolling content slides under a bar.
    @ViewBuilder
    func glassScrollEdge(_ edges: Edge.Set = .top) -> some View {
        if #available(iOS 26, *) { self.scrollEdgeEffectStyle(.soft, for: edges) } else { self }
    }

    /// The tab bar shrinks to its selected item while the user scrolls down.
    @ViewBuilder
    func glassTabBar() -> some View {
        if #available(iOS 26, *) { self.tabBarMinimizeBehavior(.onScrollDown) } else { self }
    }
}

/// Groups several glass controls so they blend and morph as one when they are
/// close together. Plain container before iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = Theme.Spacing.sm
    @ViewBuilder var content: () -> Content
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
