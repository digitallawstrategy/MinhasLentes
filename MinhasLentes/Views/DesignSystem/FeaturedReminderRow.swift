import SwiftUI

/// Linha de lembrete em destaque: ícone + título/detalhe + um anel pequeno com o número de dias.
/// O anel é só reforço visual (mesma informação já está no texto) — decorativo, oculto do
/// VoiceOver para não duplicar o anúncio.
struct FeaturedReminderRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let ringValue: String
    var ringFraction: Double = 1
    var tone: AppStatusTone = .informative
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            }
        }
        .buttonStyle(.plain)
        .pressScale()
        .accessibilityElement(children: .combine)
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
