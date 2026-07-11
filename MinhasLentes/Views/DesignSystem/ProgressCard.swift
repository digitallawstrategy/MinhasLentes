import SwiftUI

/// Cartão de contagem regressiva — título, frase de situação colorida pelo tom e uma barra de
/// progresso. Usado para prazos (limpeza periódica, validade de solução, substituição de estojo).
struct ProgressCard: View {
    let title: String
    let situationText: String
    let fraction: Double
    var tone: AppStatusTone = .informative

    var body: some View {
        AppCard {
            SectionHeader(title)
            Text(situationText)
                .font(AppTypography.footnote.weight(.medium))
                .foregroundStyle(tone.color)
            ProgressBarView(fraction: fraction, tint: tone.color)
                .animation(AppAnimation.standard, value: fraction)
        }
    }
}

#Preview {
    ProgressCard(title: "Limpeza periódica", situationText: "Faltam 6 dia(s)", fraction: 0.6, tone: .success)
        .padding()
}
