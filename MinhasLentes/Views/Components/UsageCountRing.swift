import SwiftUI

/// Anel de usos restantes com só o número dentro, no espírito do anel de atividade da Apple: o
/// número dentro do círculo é decorativo, de tamanho fixo (não escala com Dynamic Type), e o
/// texto de verdade — o que precisa ser lido em qualquer tamanho de fonte — mora sempre fora do
/// anel, em texto normal, responsabilidade de quem usa este componente.
///
/// Antes, o número usava `AppTypography.metricValue` (`.largeTitle`, que ESCALA com Dynamic
/// Type) dentro de um anel de diâmetro fixo. Num tamanho de acessibilidade grande, `.largeTitle`
/// passa facilmente de 60-70pt; nem `minimumScaleFactor(0.8)` segura isso dentro de um círculo de
/// 72-108pt sem tocar o traço — a correção anterior só reduzia o sintoma, não a causa. Aqui o
/// número usa um tamanho fixo, proporcional só ao diâmetro do anel: nunca cresce com a
/// configuração de texto do usuário, então nunca mais encosta no traço, em nenhum tamanho.
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
                // Tamanho fixo (não um estilo de texto do sistema como .largeTitle): de
                // propósito, para o número nunca escalar com Dynamic Type. 0.32x o diâmetro dá
                // uma leitura confortável em qualquer tamanho de anel usado no app hoje (72-108).
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
