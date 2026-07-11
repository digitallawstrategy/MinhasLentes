import SwiftUI

/// Linha tocável de ícone + título + detalhe + chevron — o mesmo formato usado tanto para um
/// par em uso quanto para um lembrete de prazo. Antes eram duas Views quase idênticas
/// (`pairSummaryRow` e `reminderRow`); esta é a versão única e reutilizável das duas.
struct ReminderCard: View {
    var systemImage: String?
    var emoji: String?
    let title: String
    let detail: String
    var tone: AppStatusTone = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                leadingGlyph
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.subheadlineMedium)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leadingGlyph: some View {
        if let emoji {
            Text(emoji)
                .accessibilityHidden(true)
        } else if let systemImage {
            Image(systemName: systemImage)
                .foregroundStyle(tone.color)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm) {
        ReminderCard(emoji: "🟢", title: "Par direito", detail: "51 de 60 usos restantes", action: {})
        ReminderCard(systemImage: "shippingbox", title: "Estojo", detail: "Substituição em 12 dia(s)", tone: .informative, action: {})
        ReminderCard(systemImage: "tray.full", title: "Estoque", detail: "1 caixa vencendo em breve", tone: .warning, action: {})
    }
    .padding()
}
