import SwiftUI

/// Anel de usos restantes com só o número dentro — o rótulo completo ("restantes") fica sempre
/// fora do anel, responsabilidade de quem usa este componente. Antes, o número e "restantes"
/// dividiam o mesmo círculo de tamanho fixo; em Dynamic Type grande, o traço do anel espremia
/// as duas linhas de texto até sobrepor, e a correção anterior (`minimumScaleFactor` bem
/// agressivo) só escondia o sintoma. Um número sozinho, sem rótulo, cabe no anel em qualquer
/// tamanho de fonte sem precisar encolher de forma extrema.
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
                .font(AppTypography.metricValue)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(value)))
                .animation(reduceMotion ? nil : .spring(duration: 0.5), value: value)
                .padding(.horizontal, 4)
        }
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        UsageCountRing(value: 58, remainingFraction: 0.72, tint: .green)
        UsageCountRing(value: 3, remainingFraction: 0.08, tint: .red, diameter: 108, lineWidth: 14)
    }
    .padding()
}
