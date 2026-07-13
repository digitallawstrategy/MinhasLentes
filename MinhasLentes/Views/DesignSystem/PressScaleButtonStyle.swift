import SwiftUI

/// Leve encolhimento (0.98) ao pressionar — a microinteração de toque da referência visual
/// (`modelodesign.png`). Implementado como gesto simultâneo (não `ButtonStyle`) de propósito:
/// só um `.buttonStyle(...)` por `Button` tem efeito (o mais próximo do `Button` vence, não
/// compõe), então isto precisa funcionar em cima de `.borderedProminent`/`.bordered` já
/// aplicados, sem substituí-los. Some sozinho com Reduce Motion.
private struct PressScaleModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(!reduceMotion && isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}
