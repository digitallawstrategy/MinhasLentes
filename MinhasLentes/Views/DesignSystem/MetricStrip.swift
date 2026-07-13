import SwiftUI

/// Um item de `MetricStrip` — um número/valor curto + um rótulo, ex.: "8" / "Disponíveis".
struct MetricStripItem: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    var tone: AppStatusTone = .neutral
}

/// Faixa de 2-3 métricas compactas lado a lado, dentro de um `AppCard` — para resumos que hoje
/// são uma lista de `StatRow` (Estoque, Solução): números que se leem num relance, não um rótulo
/// e valor forçados na mesma linha um do lado do outro.
struct MetricStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [MetricStripItem]

    var body: some View {
        // Em tamanhos de acessibilidade, 2-3 colunas lado a lado não cabem mais — valor e
        // rótulo quebravam no meio da palavra e a data truncava ("28/01/2..."). Cada métrica
        // vira um bloco vertical próprio (valor acima, rótulo abaixo), igual ao resto do texto
        // da tela: nada divide a linha com outro elemento, então nada precisa espremer.
        //
        // Achado real: uma versão anterior manteve valor e rótulo lado a lado (`HStack`) com
        // `.fixedSize()` só no valor — numa data longa ("28/01/2027"), isso consumia quase toda
        // a largura da linha e sobrava uma coluna de poucos pontos para o rótulo, que (sem
        // `lineLimit`) quebrava caractere por caractere tentando caber ali. Empilhado, os dois
        // sempre têm a largura inteira do cartão à disposição.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.value)
                            .font(AppTypography.metricCompact)
                            .foregroundStyle(item.tone == .neutral ? AppColor.primary : item.tone.color)
                        Text(item.label)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    VStack(spacing: 2) {
                        Text(item.value)
                            .font(AppTypography.metricCompact)
                            .foregroundStyle(item.tone == .neutral ? AppColor.primary : item.tone.color)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(item.label)
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)

                    if item.id != items.last?.id {
                        Divider().frame(height: 32)
                    }
                }
            }
        }
    }
}

#Preview {
    AppCard {
        MetricStrip(items: [
            MetricStripItem(value: "8", label: "Disponíveis", tone: .success),
            MetricStripItem(value: "15/09", label: "Próxima validade"),
            MetricStripItem(value: "1", label: "Estoque baixo", tone: .warning),
        ])
    }
    .padding()
    .background(AppColor.surface)
}
