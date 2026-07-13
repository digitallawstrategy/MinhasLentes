import SwiftUI

/// Linha de lembrete em destaque: ícone + título/detalhe + um anel pequeno com o número de dias.
/// O anel é só reforço visual (mesma informação já está no texto) — decorativo, oculto do
/// VoiceOver para não duplicar o anúncio.
struct FeaturedReminderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let systemImage: String
    let title: String
    let detail: String
    let ringValue: String
    var ringFraction: Double = 1
    var tone: AppStatusTone = .informative
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Em tamanhos de acessibilidade, o anel decorativo (72pt fixo) some: a mesma
            // informação já está no texto, e competir por espaço com título/detalhe já
            // multiplicados por um Dynamic Type extremo é o que ficava "pesado" nessa condição —
            // o ícone também encolhe, e o texto passa a ocupar a linha inteira.
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .pressScale()
        .accessibilityElement(children: .combine)
    }

    private var standardLayout: some View {
        // `.top`, não o `.center` padrão: quando `detail` quebra em 2-3 linhas (comum com
        // Dynamic Type maior), ícone e anel ficam ancorados no topo em vez de flutuar
        // centralizados contra um bloco de texto mais alto — é isso que lia como
        // "desalinhado" antes.
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tone.color)
                .frame(width: 48, height: 48)
                .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)

            textBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                ProgressRingView(remainingFraction: ringFraction, tint: tone.color, lineWidth: 5)
                VStack(spacing: 0) {
                    Text(ringValue)
                        .font(AppTypography.headline)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("dias")
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)

            // Mesmo papel de navegação do chevron de `ReminderCard` — só que discreto (caption,
            // .quaternary) pra não competir com o anel, que já é o ponto focal desta linha.
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityLayout: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tone.color)
                .frame(width: 40, height: 40)
                .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .accessibilityHidden(true)

            textBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.headline)
            Text(detail)
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    FeaturedReminderRow(
        systemImage: "shippingbox.fill",
        title: "Estojo",
        detail: "Substituição recomendada em 89 dia(s)",
        ringValue: "89",
        ringFraction: 0.7,
        tone: .informative,
        action: {}
    )
    .padding()
}
