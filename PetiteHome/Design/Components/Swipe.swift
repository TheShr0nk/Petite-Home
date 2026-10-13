import SwiftUI

/// Swipe a card or row to the left to reveal Delete; keep going to delete in
/// one motion. The platform's swipe-to-delete, on the cards the app draws
/// itself (they live in scroll views, not lists). Long-press offers the same
/// action for discoverability, and VoiceOver gets it as a custom action.
struct SwipeToDelete: ViewModifier {
    let title: String
    var cornerRadius: CGFloat
    let action: () -> Void

    @State private var offset: CGFloat = 0
    @State private var open = false
    private let reveal: CGFloat = 88
    private let commit: CGFloat = 180

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) { perform() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 17, weight: .medium))
                    Text(title).font(Typography.caption)
                }
                .foregroundStyle(Color(hex: 0xFFFFFF))
                .frame(width: reveal)
                .frame(maxHeight: .infinity)
            }
            .background(Theme.Colors.danger, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(offset < -8 ? 1 : 0)
            .accessibilityHidden(true)

            content
                .offset(x: offset)
                .gesture(drag)
                .onTapGesture { if open { close() } }
                .contextMenu { Button(title, systemImage: "trash", role: .destructive) { perform() } }
                .accessibilityAction(named: title) { perform() }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(Motion.select, value: offset)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                // Only a mostly-horizontal drag moves the row; vertical belongs to the scroll view.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let base: CGFloat = open ? -reveal : 0
                offset = min(0, max(-commit - 20, base + value.translation.width))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if offset < -commit { perform(); return }
                if offset < -reveal / 2 { offset = -reveal; open = true } else { close() }
            }
    }

    private func close() { offset = 0; open = false }

    private func perform() {
        SensoryFeedbackBridge.success()
        withAnimation(Motion.select) { action() }
        close()
    }
}

extension View {
    /// Left swipe reveals a Delete (or custom) action; a long swipe commits it.
    func swipeToDelete(_ title: String = "Delete", cornerRadius: CGFloat = Theme.Radius.card, action: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(title: title, cornerRadius: cornerRadius, action: action))
    }
}
