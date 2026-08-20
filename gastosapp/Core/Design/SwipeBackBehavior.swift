import SwiftUI

extension View {
    func swipeBackBehavior(isEnabled: Bool = true) -> some View {
        modifier(SwipeBackBehaviorModifier(isEnabled: isEnabled))
    }
}

private struct SwipeBackBehaviorModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var hasTriggered = false

    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(backGesture)
    }

    private var backGesture: some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .global)
            .onChanged(handleSwipeChange)
            .onEnded { _ in hasTriggered = false }
    }

    private func handleSwipeChange(_ value: DragGesture.Value) {
        guard isEnabled, !hasTriggered, isValidBackSwipe(value) else { return }
        hasTriggered = true
        dismiss()
    }

    private func isValidBackSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        let startsAtLeadingEdge = value.startLocation.x <= 32
        let predicted = value.predictedEndTranslation.width
        return startsAtLeadingEdge && horizontal > 72 && predicted > 110 && vertical < 64
    }
}
