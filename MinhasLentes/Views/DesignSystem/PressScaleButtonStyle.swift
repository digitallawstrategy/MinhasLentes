import SwiftUI

/// Leve encolhimento (0.98) ao pressionar — a microinteração de toque da referência visual
/// (`modelodesign.png`). `ButtonStyle` baseado em `configuration.isPressed`, não gesto
/// customizado: uma versão anterior usava `.simultaneousGesture(DragGesture(minimumDistance: 0))`,
/// que reconhece o toque assim que o dedo encosta e por isso disputa com o pan vertical do
/// `ScrollView`/`List` ao redor — quando o gesto de rolar começava em cima de um card/botão com
/// esse modificador, a rolagem prendia ou ficava "grudenta". Um `ButtonStyle` usa o
/// reconhecimento de toque nativo do `Button` (que já resolve tap-vs-scroll corretamente,
/// exatamente como qualquer botão do sistema dentro de uma lista), sem nenhum gesto concorrente.
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Substitui `.buttonStyle(.plain)` — não soma a ele. Só um `.buttonStyle(...)` por `Button`
    /// tem efeito (o mais próximo do `Button` na cadeia de modificadores vence, não compõe), então
    /// todo call site deste modificador não deve ter nenhum outro `.buttonStyle(...)` entre o
    /// `Button` e esta chamada. `PressScaleButtonStyle` já renderiza o label sem nenhum chrome
    /// adicional, igual a `.plain`.
    func pressScale() -> some View {
        buttonStyle(PressScaleButtonStyle())
    }
}
