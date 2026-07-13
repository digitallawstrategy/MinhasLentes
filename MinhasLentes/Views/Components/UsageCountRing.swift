import SwiftUI

/// Anel de usos restantes, no espírito do anel de atividade da Apple: só o número decorativo
/// dentro do círculo, em tamanho fixo (não escala com Dynamic Type); o texto de verdade — o que
/// precisa ser lido em qualquer tamanho de fonte — mora sempre fora do anel, responsabilidade de
/// quem usa este componente.
struct UsageCountRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Int
    let remainingFraction: Double
    var tint: Color = .accentColor
    var diameter: CGFloat = 72
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            ProgressRingView(remainingFraction: remainingFraction, tint: tint, lineWidth: lineWidth)
            Text("\(value)")
                // Tamanho fixo, proporcional ao diâmetro — nunca um estilo de texto do sistema
                // como .largeTitle, que escalaria com Dynamic Type.
                .font(.system(size: (diameter * 0.32).rounded(), weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(value)))
                .animation(reduceMotion ? nil : .spring(duration: 0.5), value: value)
                .padding(.horizontal, lineWidth)
        }
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        HStack(spacing: AppSpacing.lg) {
            UsageCountRing(value: 58, remainingFraction: 0.72, tint: .green)
            UsageCountRing(value: 9, remainingFraction: 0.08, tint: .red)
            UsageCountRing(value: 103, remainingFraction: 0.9, tint: .blue)
        }
        HStack(spacing: AppSpacing.lg) {
            UsageCountRing(value: 58, remainingFraction: 0.72, tint: .green, diameter: 108, lineWidth: 14)
            UsageCountRing(value: 103, remainingFraction: 0.9, tint: .blue, diameter: 108, lineWidth: 14)
        }
    }
    .padding()
}
