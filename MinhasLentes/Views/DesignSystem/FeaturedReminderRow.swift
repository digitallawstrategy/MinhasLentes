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
            HStack(spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(tone.color)
                    .frame(width: 44, height: 44)
                    .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    ProgressRingView(remainingFraction: ringFraction, tint: tone.color, lineWidth: 4)
                    Text(ringValue)
                        .font(AppTypography.headline)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(width: 52, height: 52)
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
