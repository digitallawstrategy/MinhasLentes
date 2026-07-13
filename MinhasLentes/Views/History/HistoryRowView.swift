import SwiftUI

/// Uma linha da lista de Histórico, representando um uso, uma limpeza ou um evento administrativo.
/// Utilitário de propósito, não decorativo — a densidade da lista continua a mesma, só o ícone
/// (agora num círculo, para se destacar da data/texto ao lado) e a data (mais compacta, já que
/// a seção acima já diz "Hoje"/"Ontem"/etc.) mudam.
struct HistoryRowView: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: item.systemImageName)
                .font(.footnote)
                .foregroundStyle(AppColor.primary)
                .frame(width: 30, height: 30)
                .background(AppColor.primary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.typeLabel)
                    .font(AppTypography.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(DateFormatting.shortWithTimeCompact.string(from: item.date))
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                    if let side = item.side {
                        Text("· \(side.displayName)")
                            .font(AppTypography.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let pairName = item.pairName {
                    Text(pairName)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
